//
// FestivalTabView.swift
// bitchat
//
// Festival mode with schedule and chat integration
//

import SwiftUI

/// Main festival mode view with tab navigation
/// Integrates schedule viewing with bitchat messaging
struct FestivalTabView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab: FestivalTab = .schedule
    
    enum FestivalTab: String, CaseIterable {
        case schedule = "Schedule"
        case chat = "Chat"
        
        var icon: String {
            switch self {
            case .schedule: return "calendar"
            case .chat: return "message"
            }
        }
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            switch selectedTab {
            case .schedule:
                FestivalScheduleView()
            case .chat:
                // Return to regular chat
                Text("Switch to Chat tab in main app")
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Custom tab bar
            tabBar
        }
    }
    
    private var tabBar: some View {
        HStack {
            ForEach(FestivalTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .foregroundColor(selectedTab == tab ? textColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(colorScheme == .dark ? Color.black : Color.white)
    }
}

// MARK: - Festival Mode Toggle

/// A view modifier that can be applied to ContentView to enable festival mode
struct FestivalModeModifier: ViewModifier {
    @Binding var isFestivalModeEnabled: Bool
    
    func body(content: Content) -> some View {
        if isFestivalModeEnabled {
            FestivalTabView()
        } else {
            content
        }
    }
}

extension View {
    func festivalMode(enabled: Binding<Bool>) -> some View {
        modifier(FestivalModeModifier(isFestivalModeEnabled: enabled))
    }
}

// MARK: - Festival Mode Menu Button

/// Button to toggle festival mode, can be added to app info or settings
struct FestivalModeButton: View {
    @Binding var isFestivalModeEnabled: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    var body: some View {
        Button(action: { isFestivalModeEnabled.toggle() }) {
            HStack {
                Image(systemName: isFestivalModeEnabled ? "tent.fill" : "tent")
                    .foregroundColor(textColor)
                
                Text(isFestivalModeEnabled ? "Exit Festival Mode" : "Enter Festival Mode")
                    .font(.system(.body, design: .monospaced))
                
                Spacer()
                
                if isFestivalModeEnabled {
                    Text("ON")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(textColor)
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(isFestivalModeEnabled ? textColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct FestivalTabView_Previews: PreviewProvider {
    static var previews: some View {
        FestivalTabView()
    }
}
#endif
