//
// FestivalAppInfoSection.swift
// bitchat
//
// Festival mode toggle section for AppInfoView
// Add this section to AppInfoView's infoContent VStack
//

import SwiftUI

/// Festival mode section to be added to AppInfoView
/// Usage: Add `FestivalAppInfoSection()` to the AppInfoView's infoContent VStack
struct FestivalAppInfoSection: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var festivalManager = FestivalModeManager.shared
    @ObservedObject var scheduleManager = FestivalScheduleManager.shared
    
    private var textColor: Color {
        colorScheme == .dark ? Color.green : Color(red: 0, green: 0.5, blue: 0)
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.8) : Color(red: 0, green: 0.5, blue: 0).opacity(0.8)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            Text("Festival Mode")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(textColor)
                .padding(.top, 8)
            
            // Festival mode toggle button
            Button(action: { festivalManager.toggle() }) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: festivalManager.isEnabled ? "tent.fill" : "tent")
                        .font(.system(size: 20))
                        .foregroundColor(textColor)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(scheduleManager.festivalData?.festival.name ?? "Festival Mode")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(textColor)
                            
                            Spacer()
                            
                            if festivalManager.isEnabled {
                                Text("ON")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(textColor)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(festivalManager.isEnabled 
                             ? "Tap to exit festival mode" 
                             : "Tap to enable schedule view and festival features")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if let festival = scheduleManager.festivalData?.festival {
                            Text("\(festival.location)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(festivalManager.isEnabled ? textColor.opacity(0.1) : Color.clear)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(textColor.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct FestivalAppInfoSection_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            FestivalAppInfoSection()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
