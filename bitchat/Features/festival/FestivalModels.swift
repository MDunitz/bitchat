//
// FestivalModels.swift
// bitchat
//
// Festival schedule data models
//

import Foundation
import SwiftUI

// MARK: - Festival Data Models

struct FestivalData: Codable {
    let festival: FestivalInfo
    let stages: [Stage]
    let sets: [ScheduledSet]
}

struct FestivalInfo: Codable {
    let name: String
    let location: String
    let dates: FestivalDates
    let gatesOpen: String
    let musicStart: String
    let musicEnd: String
}

struct FestivalDates: Codable {
    let start: String
    let end: String
}

struct Stage: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let color: String
    
    var swiftUIColor: Color {
        Color(hex: color) ?? .gray
    }
}

struct ScheduledSet: Codable, Identifiable {
    let id: String
    let artist: String
    let stage: String
    let day: String
    let start: String
    let end: String
    
    /// Parse start time as Date for the given day
    func startDate() -> Date? {
        parseDateTime(day: day, time: start)
    }
    
    /// Parse end time as Date for the given day
    func endDate() -> Date? {
        parseDateTime(day: day, time: end)
    }
    
    /// Check if this set is currently playing
    func isNowPlaying(currentDate: Date = Date()) -> Bool {
        guard let start = startDate(), let end = endDate() else { return false }
        return currentDate >= start && currentDate < end
    }
    
    /// Check if this set is coming up within the next N minutes
    func isUpcoming(within minutes: Int = 30, currentDate: Date = Date()) -> Bool {
        guard let start = startDate() else { return false }
        let threshold = currentDate.addingTimeInterval(TimeInterval(minutes * 60))
        return start > currentDate && start <= threshold
    }
    
    /// Formatted time range string (e.g., "8:30 PM - 10:00 PM")
    var timeRangeString: String {
        guard let startDate = startDate(), let endDate = endDate() else {
            return "\(start) - \(end)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
    
    private func parseDateTime(day: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.date(from: "\(day) \(time)")
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Schedule Manager

@MainActor
class FestivalScheduleManager: ObservableObject {
    static let shared = FestivalScheduleManager()
    
    @Published var festivalData: FestivalData?
    @Published var selectedDay: String?
    @Published var selectedStage: String?
    @Published var isLoaded = false
    
    private init() {
        loadSchedule()
    }
    
    func loadSchedule() {
        guard let url = Bundle.main.url(forResource: "FestivalSchedule", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(FestivalData.self, from: data) else {
            print("Failed to load festival schedule")
            return
        }
        
        self.festivalData = decoded
        self.selectedDay = decoded.festival.dates.start
        self.isLoaded = true
    }
    
    /// Get all unique days from the schedule
    var days: [String] {
        guard let data = festivalData else { return [] }
        return Array(Set(data.sets.map { $0.day })).sorted()
    }
    
    /// Get sets for a specific day, sorted by start time
    func sets(for day: String) -> [ScheduledSet] {
        guard let data = festivalData else { return [] }
        return data.sets
            .filter { $0.day == day }
            .sorted { ($0.startDate() ?? .distantPast) < ($1.startDate() ?? .distantPast) }
    }
    
    /// Get sets for a specific day and stage
    func sets(for day: String, stage: String) -> [ScheduledSet] {
        sets(for: day).filter { $0.stage == stage }
    }
    
    /// Get the currently playing sets
    var nowPlaying: [ScheduledSet] {
        guard let data = festivalData else { return [] }
        let now = Date()
        return data.sets.filter { $0.isNowPlaying(currentDate: now) }
    }
    
    /// Get upcoming sets within the next 30 minutes
    var upcomingSoon: [ScheduledSet] {
        guard let data = festivalData else { return [] }
        let now = Date()
        return data.sets
            .filter { $0.isUpcoming(within: 30, currentDate: now) }
            .sorted { ($0.startDate() ?? .distantPast) < ($1.startDate() ?? .distantPast) }
    }
    
    /// Get stage by ID
    func stage(for id: String) -> Stage? {
        festivalData?.stages.first { $0.id == id }
    }
    
    /// Format day string for display
    func formatDayForDisplay(_ day: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day) else { return day }
        
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}
