//
// FestivalContentView.swift
// bitchat
//
// Wrapper view that switches between normal chat and festival mode
//

import SwiftUI

/// Main content wrapper that shows either normal chat or festival mode
/// This view should replace ContentView() in BitchatApp.swift
struct FestivalContentView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @ObservedObject var festivalManager = FestivalModeManager.shared
    
    var body: some View {
        if festivalManager.isEnabled {
            FestivalMainView()
                .environmentObject(viewModel)
        } else {
            ContentView()
        }
    }
}

/// Festival mode main view with bottom tab navigation
struct FestivalMainView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedTab: FestivalTab = .schedule
    
    enum FestivalTab: String, CaseIterable {
        case schedule = "Schedule"
        case chat = "Mesh Chat"
        case info = "Info"
        
        var icon: String {
            switch self {
            case .schedule: return "calendar"
            case .chat: return "bubble.left.and.bubble.right"
            case .info: return "info.circle"
            }
        }
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Festival banner
            festivalBanner
            
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .schedule:
                    FestivalScheduleView()
                case .chat:
                    ContentView()
                case .info:
                    FestivalInfoView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Tab bar
            tabBar
        }
        .background(backgroundColor)
    }
    
    private var festivalBanner: some View {
        HStack {
            Image(systemName: "tent.fill")
                .foregroundColor(textColor)
            
            Text(FestivalScheduleManager.shared.festivalData?.festival.name ?? "Festival Mode")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(textColor)
            
            Spacer()
            
            Button(action: { FestivalModeManager.shared.disable() }) {
                Text("Exit")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(textColor.opacity(0.1))
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(FestivalTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.rawValue)
                            .font(.system(.caption2, design: .monospaced))
                    }
                    .foregroundColor(selectedTab == tab ? textColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(backgroundColor)
    }
}

/// Festival info view with mode toggle and tips
struct FestivalInfoView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var festivalManager = FestivalModeManager.shared
    @ObservedObject var scheduleManager = FestivalScheduleManager.shared
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Festival header
                if let festival = scheduleManager.festivalData?.festival {
                    VStack(alignment: .center, spacing: 8) {
                        Text(festival.name)
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(textColor)
                        
                        Text(festival.location)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("Gates: \(festival.gatesOpen) • Music: \(festival.musicStart) - \(festival.musicEnd)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                // Tips section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Festival Tips")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(textColor)
                    
                    tipRow(icon: "wifi.slash", text: "Mesh chat works without cell service")
                    tipRow(icon: "person.2", text: "Add friends as favorites to find them later")
                    tipRow(icon: "battery.100", text: "BLE mesh is battery efficient")
                    tipRow(icon: "hand.raised.fill", text: "Triple-tap screen to wipe all data")
                }
                
                Divider()
                
                // Exit festival mode
                Button(action: { festivalManager.disable() }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Exit Festival Mode")
                    }
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(backgroundColor)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(textColor)
                .frame(width: 24)
            
            Text(text)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FestivalContentView_Previews: PreviewProvider {
    static var previews: some View {
        FestivalMainView()
    }
}
#endif
