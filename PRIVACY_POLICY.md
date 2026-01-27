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

## ⚠️ Third-Party Data Sharing (Important)

**When you use internet features, some data is sent to third-party servers.** This section explains exactly what is shared and with whom.

FestMest works fully offline via Bluetooth mesh. However, certain features require internet connectivity and share data with third-party Nostr relays:

| Feature | Data Shared | When It's Shared |
|---------|-------------|------------------|
| Location Channels | Approximate location (~150m), encrypted messages | When you tap a location channel |
| Private Messages (distant) | Encrypted messages, your public key | When messaging favorites outside Bluetooth range |
| Festival Groups | Encrypted messages, group membership | When using group chat features |

### Third-Party Nostr Relays

When internet features are active, FestMest connects to these **third-party public relays** (not operated by us):

- `wss://relay.damus.io`
- `wss://nos.lol`
- `wss://relay.primal.net`
- `wss://offchain.pub`
- `wss://nostr21.com`

**Each relay is operated by a different third party with their own privacy practices.** We have no control over how they handle data that passes through them.

### What Third-Party Relays Receive

When using internet features, relays receive:

| Data | Details |
|------|---------|
| ✅ Public Key | An ephemeral identifier (not your real identity) |
| ✅ Approximate Location | ~150 meter precision geohash (only for location channels) |
| ✅ Encrypted Content | Message content encrypted with keys only you and recipient have |
| ✅ Timestamps | When messages were sent |
| ✅ IP Address | Your network address (unless Tor is enabled) |

### What Relays Cannot Access

| Data | Why It's Protected |
|------|-------------------|
| ❌ Your Identity | We never collect names, emails, or phone numbers |
| ❌ Message Content | End-to-end encrypted; relays only see ciphertext |
| ❌ Exact Location | GPS converted to ~150m geohash before sharing |
| ❌ Your IP (with Tor) | Tor routing hides your IP from relays |

### How to Minimize Data Sharing

1. **Use Bluetooth mesh only**: Disable internet features to share no data with relays
2. **Enable Tor**: Hides your IP address from relays (enabled by default)
3. **Avoid location channels**: Use #mesh channel instead to prevent location sharing
4. **Disable when not needed**: Internet features only activate when you use them

### Tor Privacy (Optional)

FestMest includes optional Tor integration to protect your IP address from Nostr relays:
- **Default**: Tor is enabled when internet features are used
- **What it protects**: Your IP address is hidden from Nostr relays
- **How to disable**: Tor can be disabled in settings if you prefer direct connections

When Tor is enabled, relays cannot determine your real IP address or physical location from your network connection.

## ⚠️ Location Data (Important)

**FestMest can access your location, but only when you explicitly use location features.**

### When Location Is Accessed

| Feature | When Accessed | Precision | Shared With |
|---------|---------------|-----------|-------------|
| Location Channels | When you tap a location channel | ~150m (geohash) | Third-party Nostr relays |
| Friend Location | When you AND a friend both enable sharing | Precise GPS | Only that friend (encrypted) |

### How Location Works

1. **You tap a location channel** (e.g., "Nearby" or a stage channel)
2. **iOS asks for permission** (you can deny)
3. **If granted**, your GPS coordinates are converted to a **geohash** (~150m grid square)
4. **The geohash (not GPS)** is sent to Nostr relays to join the channel

### What We DON'T Do With Location

- ❌ **Never track in background** - Location only accessed when you actively use features
- ❌ **Never store history** - No location logs are kept
- ❌ **Never share precise GPS with relays** - Only ~150m geohash
- ❌ **Never use for advertising** - We have no ads
- ❌ **Never sell location data** - We don't sell any data

### How to Disable Location

1. **Don't use location channels** - Use #mesh instead
2. **Revoke permission** - Settings → FestMest → Location → Never
3. **Location features are 100% optional** - The app works fully without them

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
