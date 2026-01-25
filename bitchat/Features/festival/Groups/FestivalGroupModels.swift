//
// FestivalGroupModels.swift
// bitchat
//
// User-created festival groups with invite-chain authorization
// Designed for future encryption integration
//

import Foundation
import CryptoKit

// MARK: - Nostr Event Kinds for Festival Groups

extension NostrProtocol.EventKind {
    /// Festival group definition (replaceable)
    static let festivalGroup = NostrProtocol.EventKind(rawValue: 30078)!
    /// Group invite
    static let groupInvite = NostrProtocol.EventKind(rawValue: 30079)!
    /// Group revocation
    static let groupRevoke = NostrProtocol.EventKind(rawValue: 30080)!
    /// Group message (ephemeral)
    static let groupMessage = NostrProtocol.EventKind(rawValue: 20078)!
    /// Group membership epoch (for checkpointing)
    static let groupEpoch = NostrProtocol.EventKind(rawValue: 30081)!
}

// MARK: - Festival Group

/// A user-created group/event within a festival
struct FestivalGroup: Codable, Identifiable {
    let id: String                    // Unique group ID (derived from creator pubkey + created_at)
    let name: String
    let description: String
    let creatorPubkey: String
    let createdAt: Date
    let festivalId: String?           // Optional: ties group to a specific festival
    let geohash: String?              // Optional: location for the group
    let scheduledStart: Date?         // Optional: when the event starts
    let scheduledEnd: Date?           // Optional: when the event ends
    let channels: [GroupChannel]      // Sub-channels within this group
    let isPrivate: Bool               // If true, requires invite chain auth
    let maxDepth: Int                 // Max invite chain depth (default 5)
    
    /// Channels that exist within this group
    struct GroupChannel: Codable, Identifiable {
        let id: String
        let name: String
        let description: String
        let icon: String
    }
    
    /// Generate group ID from creator and timestamp
    static func generateId(creatorPubkey: String, createdAt: Date) -> String {
        let input = "\(creatorPubkey):\(Int(createdAt.timeIntervalSince1970))"
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Invite Chain

/// An invite in the authorization chain
struct GroupInvite: Codable {
    let groupId: String
    let inviterPubkey: String         // Who created this invite
    let inviteePubkey: String         // Who is being invited
    let createdAt: Date
    let signature: String             // Schnorr signature of the invite data
    let parentInviteId: String?       // ID of the invite that authorized the inviter (nil for root)
    let depth: Int                    // How deep in the chain (0 = invited by creator)
    
    /// Unique ID for this invite
    var id: String {
        let input = "\(groupId):\(inviterPubkey):\(inviteePubkey):\(Int(createdAt.timeIntervalSince1970))"
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
    
    /// Data that gets signed
    var signableData: Data {
        let str = "\(groupId):\(inviterPubkey):\(inviteePubkey):\(Int(createdAt.timeIntervalSince1970)):\(depth)"
        return Data(str.utf8)
    }
}

/// A revocation that invalidates an invite and all downstream invites
struct GroupRevocation: Codable {
    let groupId: String
    let revokerPubkey: String         // Who is revoking (must be upstream in chain or creator)
    let revokedPubkey: String         // Whose access is being revoked
    let createdAt: Date
    let signature: String
    let reason: String?
    
    /// Unique ID for this revocation
    var id: String {
        let input = "\(groupId):\(revokerPubkey):\(revokedPubkey):\(Int(createdAt.timeIntervalSince1970))"
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
    
    var signableData: Data {
        let str = "\(groupId):\(revokerPubkey):\(revokedPubkey):\(Int(createdAt.timeIntervalSince1970))"
        return Data(str.utf8)
    }
}

// MARK: - Invite Chain for Verification

/// Complete chain from root to a member, used for verification
struct InviteChain: Codable {
    let groupId: String
    let memberPubkey: String
    let chain: [GroupInvite]          // Ordered from root (creator's invite) to member
    
    /// Verify the entire chain is valid
    /// Returns the depth if valid, nil if invalid
    func verify(
        group: FestivalGroup,
        revocations: [GroupRevocation],
        signatureVerifier: SignatureVerifier
    ) -> Int? {
        // Empty chain means this is the creator
        if chain.isEmpty {
            return memberPubkey == group.creatorPubkey ? 0 : nil
        }
        
        // Check chain doesn't exceed max depth
        guard chain.count <= group.maxDepth else { return nil }
        
        // Build set of revoked pubkeys
        let revokedPubkeys = Set(revocations.map { $0.revokedPubkey })
        
        // Verify each link in the chain
        var expectedInviter = group.creatorPubkey
        
        for (index, invite) in chain.enumerated() {
            // Check group ID matches
            guard invite.groupId == groupId else { return nil }
            
            // Check inviter is who we expect
            guard invite.inviterPubkey == expectedInviter else { return nil }
            
            // Check depth is correct
            guard invite.depth == index else { return nil }
            
            // Check inviter is not revoked
            guard !revokedPubkeys.contains(invite.inviterPubkey) else { return nil }
            
            // Verify signature
            guard signatureVerifier.verify(
                signature: invite.signature,
                data: invite.signableData,
                pubkey: invite.inviterPubkey
            ) else { return nil }
            
            // Next link's inviter should be this invite's invitee
            expectedInviter = invite.inviteePubkey
        }
        
        // Final invitee should be the member we're verifying
        guard expectedInviter == memberPubkey else { return nil }
        
        // Check member is not revoked
        guard !revokedPubkeys.contains(memberPubkey) else { return nil }
        
        return chain.count
    }
}

// MARK: - Signature Verification Protocol (Modular for Encryption)

/// Protocol for signature operations - allows swapping implementations
protocol SignatureVerifier {
    func verify(signature: String, data: Data, pubkey: String) -> Bool
}

/// Protocol for signing operations
protocol SignatureProvider {
    func sign(data: Data) throws -> String
    var pubkey: String { get }
}

// MARK: - Schnorr Implementation (Current)

/// Schnorr signature verifier using secp256k1
struct SchnorrSignatureVerifier: SignatureVerifier {
    func verify(signature: String, data: Data, pubkey: String) -> Bool {
        // TODO: Implement actual Schnorr verification using P256K
        // For now, return true - implement with P256K.Schnorr
        guard let sigData = Data(hexString: signature),
              let pubkeyData = Data(hexString: pubkey) else {
            return false
        }
        
        // Hash the data first (BIP-340 uses SHA256)
        let hash = SHA256.hash(data: data)
        
        // Actual verification would use P256K.Schnorr.PublicKey.isValidSignature
        // Placeholder - implement in integration
        _ = sigData
        _ = pubkeyData
        _ = hash
        
        return true // Placeholder
    }
}

/// Schnorr signature provider using the user's Nostr identity
struct SchnorrSignatureProvider: SignatureProvider {
    let identity: NostrIdentity
    
    var pubkey: String {
        identity.publicKeyHex
    }
    
    func sign(data: Data) throws -> String {
        let key = try identity.schnorrSigningKey()
        let hash = SHA256.hash(data: data)
        var messageBytes = [UInt8](hash)
        var auxRand = [UInt8](repeating: 0, count: 32)
        _ = auxRand.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, 32, ptr.baseAddress!)
        }
        let signature = try key.signature(message: &messageBytes, auxiliaryRand: &auxRand)
        return signature.dataRepresentation.hexEncodedString()
    }
}

// MARK: - Future Encryption Support (Placeholder Protocol)

/// Protocol for group message encryption - implement later
protocol GroupMessageEncryptor {
    /// Encrypt a message for a group
    func encrypt(content: String, groupId: String, senderChain: InviteChain) throws -> String
    
    /// Decrypt a message from a group
    func decrypt(ciphertext: String, groupId: String, senderPubkey: String) throws -> String
}

/// Placeholder: No encryption (cleartext)
struct CleartextGroupEncryptor: GroupMessageEncryptor {
    func encrypt(content: String, groupId: String, senderChain: InviteChain) throws -> String {
        return content // No encryption
    }
    
    func decrypt(ciphertext: String, groupId: String, senderPubkey: String) throws -> String {
        return ciphertext // No decryption needed
    }
}

/// Future: Tree-based key derivation encryption
/// Each node in the invite tree derives keys from their parent
/// Revoking a node rotates keys for that subtree
// struct TreeKeyEncryptor: GroupMessageEncryptor {
//     // Key derivation: childKey = HKDF(parentKey, childPubkey)
//     // Message encryption: XChaCha20-Poly1305 with derived key
//     // Revocation: parent generates new key, re-derives for remaining children
// }

// MARK: - Membership Epoch (Optimization for Long Chains)

/// Periodic snapshot of valid members, signed by creator
/// Allows O(1) verification for members in the snapshot
struct MembershipEpoch: Codable {
    let groupId: String
    let epochNumber: Int
    let createdAt: Date
    let creatorSignature: String
    let validMembers: [String]        // Pubkeys of all valid members at this epoch
    let revokedSinceLastEpoch: [String]
    
    var id: String {
        "\(groupId):epoch:\(epochNumber)"
    }
    
    /// Check if a pubkey is valid in this epoch
    func isMember(_ pubkey: String) -> Bool {
        validMembers.contains(pubkey)
    }
}

// MARK: - Nostr Event Conversion

extension FestivalGroup {
    /// Convert to Nostr event for publishing
    func toNostrEvent(signer: SignatureProvider) throws -> NostrEvent {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let contentData = try encoder.encode(self)
        let content = String(data: contentData, encoding: .utf8) ?? ""
        
        var tags: [[String]] = [
            ["d", id],  // NIP-33: replaceable event identifier
        ]
        if let festivalId = festivalId {
            tags.append(["festival", festivalId])
        }
        if let geohash = geohash {
            tags.append(["g", geohash])
        }
        
        // Create unsigned event, sign externally
        return NostrEvent(
            pubkey: signer.pubkey,
            createdAt: createdAt,
            kind: .festivalGroup,
            tags: tags,
            content: content
        )
    }
    
    /// Parse from Nostr event
    static func from(event: NostrEvent) throws -> FestivalGroup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let data = event.content.data(using: .utf8) else {
            throw FestivalGroupError.invalidEventContent
        }
        return try decoder.decode(FestivalGroup.self, from: data)
    }
}

extension GroupInvite {
    /// Convert to Nostr event
    func toNostrEvent(signer: SignatureProvider) throws -> NostrEvent {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let contentData = try encoder.encode(self)
        let content = String(data: contentData, encoding: .utf8) ?? ""
        
        let tags: [[String]] = [
            ["d", id],
            ["group", groupId],
            ["p", inviteePubkey],  // Tag the invitee
        ]
        
        return NostrEvent(
            pubkey: signer.pubkey,
            createdAt: createdAt,
            kind: .groupInvite,
            tags: tags,
            content: content
        )
    }
    
    static func from(event: NostrEvent) throws -> GroupInvite {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let data = event.content.data(using: .utf8) else {
            throw FestivalGroupError.invalidEventContent
        }
        return try decoder.decode(GroupInvite.self, from: data)
    }
}

extension GroupRevocation {
    /// Convert to Nostr event
    func toNostrEvent(signer: SignatureProvider) throws -> NostrEvent {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let contentData = try encoder.encode(self)
        let content = String(data: contentData, encoding: .utf8) ?? ""
        
        let tags: [[String]] = [
            ["d", id],
            ["group", groupId],
            ["p", revokedPubkey],  // Tag the revoked user
        ]
        
        return NostrEvent(
            pubkey: signer.pubkey,
            createdAt: createdAt,
            kind: .groupRevoke,
            tags: tags,
            content: content
        )
    }
    
    static func from(event: NostrEvent) throws -> GroupRevocation {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let data = event.content.data(using: .utf8) else {
            throw FestivalGroupError.invalidEventContent
        }
        return try decoder.decode(GroupRevocation.self, from: data)
    }
}

// MARK: - Errors

enum FestivalGroupError: Error {
    case invalidEventContent
    case invalidSignature
    case inviteChainTooDeep
    case notAuthorizedToInvite
    case notAuthorizedToRevoke
    case memberAlreadyRevoked
    case groupNotFound
    case encryptionNotConfigured
}
