//
// FestivalModeManager.swift
// bitchat
//
// Global state manager for festival mode
//

import SwiftUI
import Combine

/// Manages festival mode state across the app
/// Persists to UserDefaults so festival mode survives app restarts
@MainActor
class FestivalModeManager: ObservableObject {
    static let shared = FestivalModeManager()
    
    private let defaults = UserDefaults.standard
    private let enabledKey = "festivalModeEnabled"
    
    /// Whether festival mode is currently enabled
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: enabledKey)
        }
    }
    
    private init() {
        self.isEnabled = defaults.bool(forKey: enabledKey)
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
