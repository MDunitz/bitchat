//
// FestivalModeManager.swift
// FestMest
//
// Global state manager for festival mode
//

import SwiftUI
import Combine

/// Manages festival mode state across the app
/// Persists to UserDefaults so festival mode survives app restarts
/// For FestMest, festival mode defaults to ON (true)
@MainActor
class FestivalModeManager: ObservableObject {
    static let shared = FestivalModeManager()
    
    private let defaults = UserDefaults.standard
    private let enabledKey = "festivalModeEnabled"
    private let hasLaunchedKey = "festivalModeHasLaunched"
    
    /// Whether festival mode is currently enabled
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
        }
    }
    
    private init() {
        // For FestMest: default to true on first launch
        // After first launch, respect user preference
        if defaults.bool(forKey: hasLaunchedKey) {
            // Returning user - use their saved preference
            self.isEnabled = defaults.bool(forKey: enabledKey)
        } else {
            // First launch - default to festival mode ON
            self.isEnabled = true
            defaults.set(true, forKey: enabledKey)
            defaults.set(true, forKey: hasLaunchedKey)
        }
    }
    
    /// Toggle festival mode on/off
    func toggle() {
        isEnabled.toggle()
    }
    
    /// Enable festival mode
    func enable() {
        isEnabled = true
    }
    
    /// Disable festival mode
    func disable() {
        isEnabled = false
    }
}
