//
// FriendLocationService.swift
// bitchat
//
// Location sharing service for mutual favorites at festivals
//

import Foundation
import CoreLocation
import Combine

/// Represents a friend's shared location
struct FriendLocation: Identifiable, Equatable {
    let id: Data  // Noise public key
    let nickname: String
    let coordinate: CLLocationCoordinate2D
    let accuracy: CLLocationAccuracy
    let timestamp: Date
    let isStale: Bool  // True if location is older than staleness threshold
    
    static func == (lhs: FriendLocation, rhs: FriendLocation) -> Bool {
        lhs.id == rhs.id && lhs.timestamp == rhs.timestamp
    }
}

/// Location update packet payload
/// Sent via BLE mesh to mutual favorites only
struct LocationSharePayload: Codable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double  // meters
    let timestamp: UInt64  // milliseconds since epoch
    
    /// Encode to compact binary format (24 bytes)
    /// Layout: lat (8) + lon (8) + accuracy (4) + timestamp (4, offset from epoch)
    func toData() -> Data {
        var data = Data()
        var lat = latitude
        var lon = longitude
        var acc = Float(accuracy)
        let ts = UInt32(timestamp / 1000 - 1700000000)  // Offset to save bytes
        
        data.append(Data(bytes: &lat, count: 8))
        data.append(Data(bytes: &lon, count: 8))
        data.append(Data(bytes: &acc, count: 4))
        withUnsafeBytes(of: ts) { data.append(contentsOf: $0) }
        
        return data
    }
    
    /// Decode from compact binary format
    static func fromData(_ data: Data) -> LocationSharePayload? {
        guard data.count >= 24 else { return nil }
        
        let lat = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Double.self) }
        let lon = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Double.self) }
        let acc = data.withUnsafeBytes { $0.load(fromByteOffset: 16, as: Float.self) }
        let ts = data.withUnsafeBytes { $0.load(fromByteOffset: 20, as: UInt32.self) }
        
        return LocationSharePayload(
            latitude: lat,
            longitude: lon,
            accuracy: Double(acc),
            timestamp: (UInt64(ts) + 1700000000) * 1000
        )
    }
}

/// Manages location sharing with mutual favorites
@MainActor
class FriendLocationService: NSObject, ObservableObject {
    static let shared = FriendLocationService()
    
    // MARK: - Configuration
    
    /// How often to broadcast location (seconds)
    private let broadcastInterval: TimeInterval = 30
    
    /// How old a location can be before considered stale (seconds)
    private let stalenessThreshold: TimeInterval = 120
    
    /// Custom packet type for location sharing (uses reserved range)
    /// This should be added to the packet type enum in BitchatPacket
    static let locationSharePacketType: UInt8 = 0x20
    
    // MARK: - Published State
    
    @Published private(set) var isSharing = false
    @Published private(set) var friendLocations: [Data: FriendLocation] = [:]
    @Published private(set) var lastBroadcastTime: Date?
    @Published private(set) var myLocation: CLLocation?
    
    // MARK: - Private Properties
    
    private var locationManager: CLLocationManager?
    private var broadcastTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Get list of friend locations, excluding stale ones
    var activeFriendLocations: [FriendLocation] {
        friendLocations.values
            .filter { !$0.isStale }
            .sorted { $0.nickname < $1.nickname }
    }
    
    /// Get mutual favorites that have shared their location
    var locatedFriends: [FriendLocation] {
        friendLocations.values
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Lifecycle
    
    private override init() {
        super.init()
        setupStalenessTimer()
    }
    
    // MARK: - Public API
    
    /// Start sharing location with mutual favorites
    func startSharing() {
        guard !isSharing else { return }
        
        setupLocationManager()
        locationManager?.startUpdatingLocation()
        startBroadcastTimer()
        isSharing = true
        
        print("📍 FriendLocationService: Started location sharing")
    }
    
    /// Stop sharing location
    func stopSharing() {
        guard isSharing else { return }
        
        locationManager?.stopUpdatingLocation()
        broadcastTimer?.invalidate()
        broadcastTimer = nil
        isSharing = false
        
        print("📍 FriendLocationService: Stopped location sharing")
    }
    
    /// Toggle location sharing
    func toggleSharing() {
        if isSharing {
            stopSharing()
        } else {
            startSharing()
        }
    }
    
    /// Process incoming location share packet
    /// Call this from the packet handler when receiving locationSharePacketType
    func handleLocationPacket(senderNoiseKey: Data, senderNickname: String, payload: Data) {
        // Only process from mutual favorites
        guard FavoritesPersistenceService.shared.favorites[senderNoiseKey]?.isMutual == true else {
            print("📍 Ignoring location from non-mutual favorite")
            return
        }
        
        guard let location = LocationSharePayload.fromData(payload) else {
            print("📍 Failed to decode location payload")
            return
        }
        
        let friendLocation = FriendLocation(
            id: senderNoiseKey,
            nickname: senderNickname,
            coordinate: CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            ),
            accuracy: location.accuracy,
            timestamp: Date(timeIntervalSince1970: Double(location.timestamp) / 1000),
            isStale: false
        )
        
        friendLocations[senderNoiseKey] = friendLocation
        print("📍 Updated location for \(senderNickname)")
    }
    
    /// Clear all friend locations (e.g., when leaving festival mode)
    func clearLocations() {
        friendLocations.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupLocationManager() {
        guard locationManager == nil else { return }
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = 10  // Update every 10 meters
        locationManager?.allowsBackgroundLocationUpdates = false
        locationManager?.requestWhenInUseAuthorization()
    }
    
    private func startBroadcastTimer() {
        broadcastTimer?.invalidate()
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: broadcastInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.broadcastLocation()
            }
        }
    }
    
    private func broadcastLocation() {
        guard let location = myLocation else { return }
        
        let payload = LocationSharePayload(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: UInt64(location.timestamp.timeIntervalSince1970 * 1000)
        )
        
        // Get all mutual favorites to send to
        let mutualFavorites = FavoritesPersistenceService.shared.favorites.values
            .filter { $0.isMutual }
        
        guard !mutualFavorites.isEmpty else {
            print("📍 No mutual favorites to share location with")
            return
        }
        
        // Create packet and broadcast
        // NOTE: This needs to be integrated with the actual mesh service
        // The packet should be sent via the existing BLE mesh infrastructure
        let data = payload.toData()
        
        print("📍 Broadcasting location to \(mutualFavorites.count) mutual favorites")
        lastBroadcastTime = Date()
        
        // TODO: Integrate with MeshService to actually send the packet
        // Example integration point:
        // meshService.broadcastToFavorites(
        //     type: FriendLocationService.locationSharePacketType,
        //     payload: data
        // )
    }
    
    private func setupStalenessTimer() {
        // Check for stale locations every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStaleness()
            }
        }
    }
    
    private func updateStaleness() {
        let now = Date()
        var updated = false
        
        for (key, location) in friendLocations {
            let age = now.timeIntervalSince(location.timestamp)
            let shouldBeStale = age > stalenessThreshold
            
            if location.isStale != shouldBeStale {
                friendLocations[key] = FriendLocation(
                    id: location.id,
                    nickname: location.nickname,
                    coordinate: location.coordinate,
                    accuracy: location.accuracy,
                    timestamp: location.timestamp,
                    isStale: shouldBeStale
                )
                updated = true
            }
        }
        
        if updated {
            objectWillChange.send()
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension FriendLocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.myLocation = location
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("📍 Location error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.isSharing {
                    manager.startUpdatingLocation()
                }
            case .denied, .restricted:
                self.stopSharing()
            default:
                break
            }
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let friendLocationUpdated = Notification.Name("friendLocationUpdated")
}
