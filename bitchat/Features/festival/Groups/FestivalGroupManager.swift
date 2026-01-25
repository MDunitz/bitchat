//
// FestivalGroupManager.swift
// bitchat
//
// Service for creating and managing festival groups with invite-chain auth
// Uses local caching for O(1) membership verification after first check
//

import Foundation
import Combine

/// Manages user-created festival groups and their authorization chains
@MainActor
final class FestivalGroupManager: ObservableObject {
    static let shared = FestivalGroupManager()
    
    // MARK: - Published State
    
    @Published private(set) var myGroups: [FestivalGroup] = []           // Groups I created
    @Published private(set) var joinedGroups: [FestivalGroup] = []       // Groups I'm a member of
    @Published private(set) var pendingInvites: [GroupInvite] = []       // Invites I haven't accepted
    @Published private(set) var isLoading = false
    
    // MARK: - Dependencies
    
    private let signatureVerifier: SignatureVerifier
    private let encryptor: GroupMessageEncryptor
    private var signatureProvider: SignatureProvider?
    
    // MARK: - Internal State
    
    /// All known groups (by ID)
    private var groups: [String: FestivalGroup] = [:]
    
    /// All invites for each group (by group ID)
    private var invitesByGroup: [String: [GroupInvite]] = [:]
    
    /// All revocations for each group (by group ID)
    private var revocationsByGroup: [String: [GroupRevocation]] = [:]
    
    /// My invite chains for groups I'm a member of (by group ID)
    private var myChains: [String: InviteChain] = [:]
    
    // MARK: - Membership Cache (Key Performance Optimization)
    
    /// Cache of verified members per group
    /// Key: groupId, Value: Set of pubkeys verified as members
    /// This provides O(1) lookups after first verification
    private var verifiedMembersCache: [String: Set<String>] = [:]
    
    /// Cache of verified invite chains per group
    /// Key: groupId, Value: Dictionary of pubkey -> their verified InviteChain
    /// Allows re-verification without re-fetching chain data
    private var verifiedChainsCache: [String: [String: InviteChain]] = [:]
    
    /// Timestamp of last revocation per group (for cache invalidation)
    private var lastRevocationTime: [String: Date] = [:]
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init(
        signatureVerifier: SignatureVerifier = SchnorrSignatureVerifier(),
        encryptor: GroupMessageEncryptor = CleartextGroupEncryptor()
    ) {
        self.signatureVerifier = signatureVerifier
        self.encryptor = encryptor
    }
    
    /// Configure with the user's signing identity
    func configure(with identity: NostrIdentity) {
        self.signatureProvider = SchnorrSignatureProvider(identity: identity)
        refreshMyMemberships()
    }
    
    // MARK: - Group Creation
    
    /// Create a new festival group
    func createGroup(
        name: String,
        description: String,
        festivalId: String? = nil,
        geohash: String? = nil,
        scheduledStart: Date? = nil,
        scheduledEnd: Date? = nil,
        channels: [FestivalGroup.GroupChannel] = [],
        isPrivate: Bool = true,
        maxDepth: Int = 5
    ) throws -> FestivalGroup {
        guard let signer = signatureProvider else {
            throw FestivalGroupError.encryptionNotConfigured
        }
        
        let now = Date()
        let id = FestivalGroup.generateId(creatorPubkey: signer.pubkey, createdAt: now)
        
        // Default channels if none provided
        let groupChannels = channels.isEmpty ? [
            FestivalGroup.GroupChannel(id: "general", name: "#general", description: "Main chat", icon: "bubble.left.and.bubble.right"),
            FestivalGroup.GroupChannel(id: "announcements", name: "#announcements", description: "Updates from organizers", icon: "megaphone")
        ] : channels
        
        let group = FestivalGroup(
            id: id,
            name: name,
            description: description,
            creatorPubkey: signer.pubkey,
            createdAt: now,
            festivalId: festivalId,
            geohash: geohash,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            channels: groupChannels,
            isPrivate: isPrivate,
            maxDepth: maxDepth
        )
        
        // Store locally
        groups[id] = group
        myGroups.append(group)
        
        // Creator has an implicit empty chain (they are the root)
        myChains[id] = InviteChain(groupId: id, memberPubkey: signer.pubkey, chain: [])
        
        // Pre-cache creator as verified member
        verifiedMembersCache[id] = [signer.pubkey]
        
        return group
    }
    
    /// Publish a group to Nostr relays
    func publishGroup(_ group: FestivalGroup, to relayUrls: [String]? = nil) async throws {
        guard let signer = signatureProvider else {
            throw FestivalGroupError.encryptionNotConfigured
        }
        
        let event = try group.toNostrEvent(signer: signer)
        // Sign the event (implementation depends on NostrIdentity integration)
        // event = try event.sign(with: signer)
        
        // Send to relays
        NostrRelayManager.shared.sendEvent(event, to: relayUrls)
    }
    
    // MARK: - Invitations
    
    /// Create an invite for someone to join a group
    func createInvite(
        groupId: String,
        inviteePubkey: String
    ) throws -> GroupInvite {
        guard let signer = signatureProvider else {
            throw FestivalGroupError.encryptionNotConfigured
        }
        
        guard let group = groups[groupId] else {
            throw FestivalGroupError.groupNotFound
        }
        
        // Check I have authority to invite
        guard let myChain = myChains[groupId] else {
            throw FestivalGroupError.notAuthorizedToInvite
        }
        
        let myDepth = myChain.chain.count
        let newDepth = myDepth + 1
        
        // Check we won't exceed max depth
        guard newDepth <= group.maxDepth else {
            throw FestivalGroupError.inviteChainTooDeep
        }
        
        // Check invitee isn't already revoked
        let revocations = revocationsByGroup[groupId] ?? []
        let revokedPubkeys = Set(revocations.map { $0.revokedPubkey })
        guard !revokedPubkeys.contains(inviteePubkey) else {
            throw FestivalGroupError.memberAlreadyRevoked
        }
        
        let now = Date()
        let parentInviteId = myChain.chain.last?.id
        
        // Create the invite
        var invite = GroupInvite(
            groupId: groupId,
            inviterPubkey: signer.pubkey,
            inviteePubkey: inviteePubkey,
            createdAt: now,
            signature: "",  // Will be set below
            parentInviteId: parentInviteId,
            depth: newDepth
        )
        
        // Sign the invite
        let signature = try signer.sign(data: invite.signableData)
        invite = GroupInvite(
            groupId: invite.groupId,
            inviterPubkey: invite.inviterPubkey,
            inviteePubkey: invite.inviteePubkey,
            createdAt: invite.createdAt,
            signature: signature,
            parentInviteId: invite.parentInviteId,
            depth: invite.depth
        )
        
        // Store locally
        var groupInvites = invitesByGroup[groupId] ?? []
        groupInvites.append(invite)
        invitesByGroup[groupId] = groupInvites
        
        return invite
    }
    
    /// Accept an invite and build my chain
    func acceptInvite(_ invite: GroupInvite) throws {
        guard let signer = signatureProvider else {
            throw FestivalGroupError.encryptionNotConfigured
        }
        
        // Verify the invite is for me
        guard invite.inviteePubkey == signer.pubkey else {
            throw FestivalGroupError.notAuthorizedToInvite
        }
        
        guard let group = groups[invite.groupId] else {
            throw FestivalGroupError.groupNotFound
        }
        
        // Build the chain by walking back through parent invites
        var chain: [GroupInvite] = []
        var currentInvite: GroupInvite? = invite
        
        while let inv = currentInvite {
            chain.insert(inv, at: 0)  // Build chain from root to leaf
            
            if let parentId = inv.parentInviteId {
                // Find parent invite
                let groupInvites = invitesByGroup[invite.groupId] ?? []
                currentInvite = groupInvites.first { $0.id == parentId }
            } else {
                // No parent = this was invited directly by creator
                currentInvite = nil
            }
        }
        
        let inviteChain = InviteChain(
            groupId: invite.groupId,
            memberPubkey: signer.pubkey,
            chain: chain
        )
        
        // Verify the chain
        let revocations = revocationsByGroup[invite.groupId] ?? []
        guard inviteChain.verify(
            group: group,
            revocations: revocations,
            signatureVerifier: signatureVerifier
        ) != nil else {
            throw FestivalGroupError.invalidSignature
        }
        
        // Store my chain
        myChains[invite.groupId] = inviteChain
        
        // Cache myself as verified
        var verifiedMembers = verifiedMembersCache[invite.groupId] ?? []
        verifiedMembers.insert(signer.pubkey)
        verifiedMembersCache[invite.groupId] = verifiedMembers
        
        // Cache my chain
        var chainsCache = verifiedChainsCache[invite.groupId] ?? [:]
        chainsCache[signer.pubkey] = inviteChain
        verifiedChainsCache[invite.groupId] = chainsCache
        
        // Add to joined groups
        if !joinedGroups.contains(where: { $0.id == group.id }) {
            joinedGroups.append(group)
        }
        
        // Remove from pending
        pendingInvites.removeAll { $0.id == invite.id }
    }
    
    // MARK: - Revocation
    
    /// Revoke someone's access (and everyone they invited)
    func revoke(
        groupId: String,
        memberPubkey: String,
        reason: String? = nil
    ) throws -> GroupRevocation {
        guard let signer = signatureProvider else {
            throw FestivalGroupError.encryptionNotConfigured
        }
        
        guard let group = groups[groupId] else {
            throw FestivalGroupError.groupNotFound
        }
        
        // Check I have authority to revoke
        // Can revoke if: I'm the creator, or I'm upstream in their chain
        let isCreator = group.creatorPubkey == signer.pubkey
        let isUpstream = isInMyDownstream(groupId: groupId, pubkey: memberPubkey)
        
        guard isCreator || isUpstream else {
            throw FestivalGroupError.notAuthorizedToRevoke
        }
        
        let now = Date()
        
        var revocation = GroupRevocation(
            groupId: groupId,
            revokerPubkey: signer.pubkey,
            revokedPubkey: memberPubkey,
            createdAt: now,
            signature: "",
            reason: reason
        )
        
        // Sign the revocation
        let signature = try signer.sign(data: revocation.signableData)
        revocation = GroupRevocation(
            groupId: revocation.groupId,
            revokerPubkey: revocation.revokerPubkey,
            revokedPubkey: revocation.revokedPubkey,
            createdAt: revocation.createdAt,
            signature: signature,
            reason: revocation.reason
        )
        
        // Store locally
        var groupRevocations = revocationsByGroup[groupId] ?? []
        groupRevocations.append(revocation)
        revocationsByGroup[groupId] = groupRevocations
        
        // IMPORTANT: Invalidate the membership cache for this group
        // This forces re-verification of all members
        invalidateCache(for: groupId)
        
        return revocation
    }
    
    /// Check if a pubkey is in my downstream (I invited them or someone I invited did)
    private func isInMyDownstream(groupId: String, pubkey: String) -> Bool {
        guard let signer = signatureProvider else { return false }
        
        let invites = invitesByGroup[groupId] ?? []
        var toCheck = Set<String>()
        var checked = Set<String>()
        
        // Start with people I directly invited
        for invite in invites where invite.inviterPubkey == signer.pubkey {
            toCheck.insert(invite.inviteePubkey)
        }
        
        // BFS through the invite tree
        while !toCheck.isEmpty {
            let current = toCheck.removeFirst()
            if current == pubkey { return true }
            checked.insert(current)
            
            // Add anyone this person invited
            for invite in invites where invite.inviterPubkey == current {
                if !checked.contains(invite.inviteePubkey) {
                    toCheck.insert(invite.inviteePubkey)
                }
            }
        }
        
        return false
    }
    
    // MARK: - Membership Verification (with Caching)
    
    /// Check if a pubkey is a valid member of a group
    /// Uses cache for O(1) lookups after first verification
    func isMember(pubkey: String, groupId: String) -> Bool {
        guard let group = groups[groupId] else { return false }
        
        // Creator is always a member (no verification needed)
        if pubkey == group.creatorPubkey { return true }
        
        // Fast path: Check cache first - O(1)
        if let verifiedMembers = verifiedMembersCache[groupId],
           verifiedMembers.contains(pubkey) {
            return true
        }
        
        // Slow path: Verify the chain - O(depth)
        // This only happens once per member per cache invalidation
        if verifyAndCacheMembership(pubkey: pubkey, groupId: groupId) {
            return true
        }
        
        return false
    }
    
    /// Verify a member's chain and cache the result if valid
    /// Returns true if member is verified, false otherwise
    private func verifyAndCacheMembership(pubkey: String, groupId: String) -> Bool {
        guard let group = groups[groupId] else { return false }
        
        // Build the invite chain for this pubkey
        guard let chain = buildInviteChain(for: pubkey, groupId: groupId) else {
            return false
        }
        
        // Verify the chain
        let revocations = revocationsByGroup[groupId] ?? []
        guard chain.verify(
            group: group,
            revocations: revocations,
            signatureVerifier: signatureVerifier
        ) != nil else {
            return false
        }
        
        // Cache the verified member
        var verifiedMembers = verifiedMembersCache[groupId] ?? []
        verifiedMembers.insert(pubkey)
        verifiedMembersCache[groupId] = verifiedMembers
        
        // Cache the chain for potential re-verification
        var chainsCache = verifiedChainsCache[groupId] ?? [:]
        chainsCache[pubkey] = chain
        verifiedChainsCache[groupId] = chainsCache
        
        return true
    }
    
    /// Build an invite chain for a given pubkey by walking back through invites
    private func buildInviteChain(for pubkey: String, groupId: String) -> InviteChain? {
        let invites = invitesByGroup[groupId] ?? []
        
        // Find the invite where this pubkey is the invitee
        guard let finalInvite = invites.first(where: { $0.inviteePubkey == pubkey }) else {
            return nil
        }
        
        // Walk back through parent invites to build the chain
        var chain: [GroupInvite] = []
        var currentInvite: GroupInvite? = finalInvite
        
        while let inv = currentInvite {
            chain.insert(inv, at: 0)  // Build from root to leaf
            
            if let parentId = inv.parentInviteId {
                currentInvite = invites.first { $0.id == parentId }
            } else {
                currentInvite = nil
            }
        }
        
        return InviteChain(groupId: groupId, memberPubkey: pubkey, chain: chain)
    }
    
    /// Invalidate the membership cache for a group
    /// Called when a revocation is received
    private func invalidateCache(for groupId: String) {
        verifiedMembersCache.removeValue(forKey: groupId)
        verifiedChainsCache.removeValue(forKey: groupId)
        lastRevocationTime[groupId] = Date()
        
        // Re-add creator to cache (always valid)
        if let group = groups[groupId] {
            verifiedMembersCache[groupId] = [group.creatorPubkey]
        }
    }
    
    /// Get all valid members of a group
    /// Note: This verifies all members, so it populates the cache
    func getMembers(groupId: String) -> [String] {
        guard let group = groups[groupId] else { return [] }
        
        var members = Set<String>()
        members.insert(group.creatorPubkey)
        
        let invites = invitesByGroup[groupId] ?? []
        
        // Check each invitee
        for invite in invites {
            if isMember(pubkey: invite.inviteePubkey, groupId: groupId) {
                members.insert(invite.inviteePubkey)
            }
        }
        
        return Array(members)
    }
    
    /// Get cache statistics for debugging/monitoring
    func getCacheStats(groupId: String) -> (cached: Int, total: Int) {
        let cached = verifiedMembersCache[groupId]?.count ?? 0
        let total = (invitesByGroup[groupId]?.count ?? 0) + 1  // +1 for creator
        return (cached, total)
    }
    
    // MARK: - Messaging
    
    /// Send a message to a group channel
    func sendMessage(
        content: String,
        groupId: String,
        channelId: String
    ) throws -> NostrEvent {
        guard let signer = signatureProvider else {
            throw FestivalGroupError.encryptionNotConfigured
        }
        
        guard let myChain = myChains[groupId] else {
            throw FestivalGroupError.notAuthorizedToInvite
        }
        
        // Encrypt the content (currently cleartext, but modular)
        let encryptedContent = try encryptor.encrypt(
            content: content,
            groupId: groupId,
            senderChain: myChain
        )
        
        // Build message payload
        let payload = GroupMessagePayload(
            content: encryptedContent,
            channelId: channelId,
            senderChainDepth: myChain.chain.count
        )
        
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? ""
        
        // Create ephemeral event
        let tags: [[String]] = [
            ["group", groupId],
            ["channel", channelId]
        ]
        
        return NostrEvent(
            pubkey: signer.pubkey,
            createdAt: Date(),
            kind: .groupMessage,
            tags: tags,
            content: payloadString
        )
    }
    
    // MARK: - Sync with Relays
    
    /// Subscribe to updates for a group
    func subscribeToGroup(_ groupId: String, relayUrls: [String]? = nil) {
        // Subscribe to invites for this group
        var inviteFilter = NostrFilter()
        inviteFilter.kinds = [NostrProtocol.EventKind.groupInvite.rawValue]
        // Tag filter for group
        
        NostrRelayManager.shared.subscribe(
            filter: inviteFilter,
            id: "group-invites-\(groupId)",
            relayUrls: relayUrls
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleIncomingInvite(event)
            }
        }
        
        // Subscribe to revocations
        var revokeFilter = NostrFilter()
        revokeFilter.kinds = [NostrProtocol.EventKind.groupRevoke.rawValue]
        
        NostrRelayManager.shared.subscribe(
            filter: revokeFilter,
            id: "group-revokes-\(groupId)",
            relayUrls: relayUrls
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleIncomingRevocation(event)
            }
        }
        
        // Subscribe to messages
        var messageFilter = NostrFilter()
        messageFilter.kinds = [NostrProtocol.EventKind.groupMessage.rawValue]
        
        NostrRelayManager.shared.subscribe(
            filter: messageFilter,
            id: "group-messages-\(groupId)",
            relayUrls: relayUrls
        ) { [weak self] event in
            Task { @MainActor in
                self?.handleIncomingMessage(event)
            }
        }
    }
    
    private func handleIncomingInvite(_ event: NostrEvent) {
        guard let invite = try? GroupInvite.from(event: event) else { return }
        
        // Store the invite
        var groupInvites = invitesByGroup[invite.groupId] ?? []
        if !groupInvites.contains(where: { $0.id == invite.id }) {
            groupInvites.append(invite)
            invitesByGroup[invite.groupId] = groupInvites
        }
        
        // If it's for me, add to pending
        if invite.inviteePubkey == signatureProvider?.pubkey {
            if !pendingInvites.contains(where: { $0.id == invite.id }) {
                pendingInvites.append(invite)
            }
        }
    }
    
    private func handleIncomingRevocation(_ event: NostrEvent) {
        guard let revocation = try? GroupRevocation.from(event: event) else { return }
        
        // Store the revocation
        var groupRevocations = revocationsByGroup[revocation.groupId] ?? []
        if !groupRevocations.contains(where: { $0.id == revocation.id }) {
            groupRevocations.append(revocation)
            revocationsByGroup[revocation.groupId] = groupRevocations
        }
        
        // CRITICAL: Invalidate cache when revocation arrives
        // This ensures revoked members are re-verified
        invalidateCache(for: revocation.groupId)
        
        // If I'm revoked, remove from joined groups
        if revocation.revokedPubkey == signatureProvider?.pubkey {
            joinedGroups.removeAll { $0.id == revocation.groupId }
            myChains.removeValue(forKey: revocation.groupId)
        }
        
        // Invalidate any chains that depend on the revoked user
        refreshMyMemberships()
    }
    
    private func handleIncomingMessage(_ event: NostrEvent) {
        // Verify sender is a member (uses cache - O(1) after first check)
        guard let groupTag = event.tags.first(where: { $0.first == "group" }),
              groupTag.count > 1 else { return }
        
        let groupId = groupTag[1]
        guard isMember(pubkey: event.pubkey, groupId: groupId) else {
            // Sender not authorized - drop message
            return
        }
        
        // Decrypt and process message
        // (Delegate to message handler)
    }
    
    private func refreshMyMemberships() {
        // Re-verify all my chains against current revocations
        for (groupId, chain) in myChains {
            guard let group = groups[groupId] else {
                myChains.removeValue(forKey: groupId)
                continue
            }
            
            let revocations = revocationsByGroup[groupId] ?? []
            if chain.verify(group: group, revocations: revocations, signatureVerifier: signatureVerifier) == nil {
                // My chain is no longer valid
                myChains.removeValue(forKey: groupId)
                joinedGroups.removeAll { $0.id == groupId }
            }
        }
    }
}

// MARK: - Message Payload

struct GroupMessagePayload: Codable {
    let content: String
    let channelId: String
    let senderChainDepth: Int
}
