# FestMest Privacy Policy

*Last updated: January 2026*

## Our Commitment

FestMest is designed with privacy as its foundation. We believe private communication is a fundamental human right. This policy explains how FestMest protects your privacy.

## Summary

- **No personal data collection** - We don't collect names, emails, or phone numbers
- **No central servers** - Core mesh communication happens directly between devices
- **No tracking** - We have no analytics, telemetry, or user tracking
- **Open source** - You can verify these claims by reading our code

## What Information FestMest Stores

### On Your Device Only

1. **Identity Key** 
   - A cryptographic key generated on first launch
   - Stored locally in your device's secure storage
   - Allows you to maintain "favorite" relationships across app restarts
   - Never leaves your device

2. **Nickname**
   - The display name you choose (or auto-generated)
   - Stored only on your device
   - Shared with peers you communicate with

3. **Message History** (if enabled)
   - When room owners enable retention, messages are saved locally
   - Stored encrypted on your device
   - You can delete this at any time

4. **Favorite Peers**
   - Public keys of peers you mark as favorites
   - Stored only on your device
   - Allows you to recognize these peers in future sessions

5. **Festival Settings**
   - Festival mode preferences (on/off)
   - Festival group memberships
   - Stored locally on your device

### Temporary Session Data

During each session, FestMest temporarily maintains:
- Active peer connections (forgotten when app closes)
- Routing information for message delivery
- Cached messages for offline peers (12 hours max)

## Internet Features (Nostr Protocol)

When internet connectivity is available, FestMest can optionally use the Nostr protocol for extended features. **These features only activate when you use them** - the app works fully offline via Bluetooth mesh.

### When Internet Features Are Used

FestMest connects to third-party Nostr relays for:
- **Location Channels**: Chat with nearby people via geohash-based channels
- **Private Messages to Distant Friends**: End-to-end encrypted messages to mutual favorites who are not in Bluetooth range
- **Festival Groups**: User-created group chats with invite-chain authorization

### Default Nostr Relays

When internet features are active, FestMest connects to these public relays:
- wss://relay.damus.io
- wss://nos.lol
- wss://relay.primal.net
- wss://offchain.pub
- wss://nostr21.com

These are third-party services not operated by FestMest. Each relay has its own privacy policy.

### What Nostr Relays Can See

When using internet features, the following data passes through relays:

**Relays CAN see:**
- Your ephemeral public key (not linked to your real identity)
- Approximate location as a geohash tag (~150m precision) when using location channels
- Encrypted message content (unreadable without your private key)
- Timestamps of messages
- Group membership tags (which groups you're in)

**Relays CANNOT see:**
- Your real name, phone number, or email (we never collect these)
- Decrypted message content (end-to-end encrypted)
- Your exact GPS coordinates (geohash is intentionally imprecise)
- Your IP address (when Tor is enabled)

### Tor Privacy (Optional)

FestMest includes optional Tor integration to protect your IP address from Nostr relays:
- **Default**: Tor is enabled when internet features are used
- **What it protects**: Your IP address is hidden from Nostr relays
- **How to disable**: Tor can be disabled in settings if you prefer direct connections

When Tor is enabled, relays cannot determine your real IP address or physical location from your network connection.

## Location Features

FestMest offers optional location-based features. **Location is never accessed without your explicit permission.**

### Geohash Location Channels

- Uses your approximate location (~150m precision) to join nearby chat rooms
- **Opt-in**: Only activates when you grant location permission AND tap a location channel
- Location data is converted to a geohash (imprecise grid square) before being shared
- You can revoke location permission at any time in system settings

### Friend Location Sharing

- Share your precise location with mutual favorites only
- **Double opt-in**: Both you AND your friend must enable sharing
- Location is end-to-end encrypted between friends
- Works over Bluetooth mesh (no internet required) or Nostr when online

### What We DON'T Do With Location

- We never track your location in the background
- We never store location history
- We never share precise location with relays (only ~150m geohash)
- Location is never used for advertising or profiling

## What Information is Shared

### With Other FestMest Users (Bluetooth Mesh)

When using local mesh chat, nearby peers can see:
- Your chosen nickname
- Your ephemeral public key (changes each session)
- Messages you send to public rooms or directly to them
- Your approximate Bluetooth signal strength (for connection quality)

### With Room Members

When you join a password-protected room:
- Your messages are visible to others with the password
- Your nickname appears in the member list
- Room owners can see you've joined

### With Festival Groups

When you join a festival group:
- Your public key is visible to group members
- Your messages in group channels are visible to verified members
- Your invite chain (who invited you) is cryptographically verifiable

## What We DON'T Do

FestMest **never**:
- Collects personal information
- Stores data on our servers (we have none)
- Shares data with advertisers or data brokers
- Uses analytics or telemetry
- Creates user profiles
- Requires registration or accounts
- Tracks location without explicit permission

## Encryption

All private messages use end-to-end encryption:
- **X25519** for key exchange
- **AES-256-GCM** for message encryption  
- **Ed25519/Schnorr** for digital signatures
- **Argon2id** for password-protected rooms
- **Noise Protocol** for mesh communication

## Your Rights

You have complete control:
- **Delete Everything**: Triple-tap the logo to instantly wipe all data
- **Leave Anytime**: Close the app and your presence disappears
- **No Account**: Nothing to delete from servers because there are none
- **Portability**: Your data never leaves your device unless you explicitly share it
- **Location Control**: Revoke location permission anytime in system settings
- **Tor Control**: Enable or disable Tor routing in settings

## Bluetooth & Permissions

FestMest requires Bluetooth permission to function:
- Used only for peer-to-peer communication
- Bluetooth is not used for tracking
- You can revoke this permission at any time in system settings

## Children's Privacy

FestMest does not knowingly collect information from children. The app has no age verification because it collects no personal information from anyone.

## Data Retention

- **Messages**: Deleted from memory when app closes (unless room retention is enabled)
- **Identity Key**: Persists until you delete the app
- **Favorites**: Persist until you remove them or delete the app
- **Location**: Never stored; only used momentarily to compute geohash
- **Everything Else**: Exists only during active sessions

## Security Measures

- All communication is encrypted end-to-end
- No data transmitted to our servers (there are none)
- Open source code for public audit
- Cryptographic signatures prevent tampering
- Optional Tor routing hides your IP address

## Changes to This Policy

If we update this policy:
- The "Last updated" date will change
- The updated policy will be included in the app
- No retroactive changes can affect previously collected data (since we don't collect any)

## Contact & Source Code

FestMest is built on the open-source bitchat protocol by Jack Dorsey.

- FestMest source code: [https://github.com/MDunitz/festmest](https://github.com/MDunitz/festmest)
- Original bitchat: [https://github.com/permissionlesstech/bitchat](https://github.com/permissionlesstech/bitchat)
- Open an issue on GitHub for privacy questions

## Philosophy

Privacy isn't just a feature—it's the entire point. FestMest proves that modern communication doesn't require surrendering your privacy. No accounts, no servers, no surveillance. Just people talking freely.

---

*This policy is released into the public domain under The Unlicense.*
