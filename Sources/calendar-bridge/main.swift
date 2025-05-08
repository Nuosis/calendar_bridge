//
//  main.swift
//  calendar‑bridge
//
//  Paste this file into Sources/calendar‑bridge/main.swift
//  Build with:  swift build
//

import Foundation
import EventKit
import ArgumentParser

// MARK: ‑ DTO used for JSON output
struct EventDTO: Codable {
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let notes: String?
    let attendees: [String]
}

// MARK: ‑ CLI definition
struct CalendarBridge: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Fetch macOS Calendar events (and optionally create a demo event)."
    )
    
    @Option(name: .customLong("start"),
            help: "Inclusive ISO‑8601 start (e.g. 2025‑05‑07T00:00:00Z).")
    var start: String
    
    @Option(name: .customLong("end"),
            help: "Exclusive ISO‑8601 end (e.g. 2025‑05‑08T00:00:00Z).")
    var end: String
    
    @Flag(name: .long,
          help: "Also create a demo event in the default calendar.")
    var create: Bool = false
    
    func run() throws {
        // ---------- Parse dates ----------
        func parseISO(_ value: String) -> Date? {
            // Accept plain RFC‑3339 as well as strings that include fractional seconds
            let fmt1 = ISO8601DateFormatter()
            fmt1.formatOptions = [.withInternetDateTime]            // e.g. 2025‑05‑07T00:00:00Z
            if let d = fmt1.date(from: value) { return d }

            let fmt2 = ISO8601DateFormatter()
            fmt2.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // e.g. 2025‑05‑07T00:00:00.123Z
            return fmt2.date(from: value)
        }

        guard let startDate = parseISO(start),
              let endDate   = parseISO(end) else {
            throw ValidationError("Unable to parse --start/--end; supply RFC‑3339 timestamps like 2025‑05‑07T00:00:00Z")
        }
        guard startDate < endDate else {
            throw ValidationError("--start must be earlier than --end.")
        }
        
        // ---------- Authorise ----------
        let store = EKEventStore()
        if EKEventStore.authorizationStatus(for: .event) != .authorized {
            let sema = DispatchSemaphore(value: 0)

            if #available(macOS 14.0, *) {
                store.requestFullAccessToEvents { granted, err in
                    if !granted {
                        fputs("calendar‑bridge: Calendar access not granted: \(err?.localizedDescription ?? "user denied")\n", stderr)
                        Darwin.exit(EXIT_FAILURE)
                    }
                    sema.signal()
                }
            } else {
                // Fallback for macOS 13 and earlier
                store.requestAccess(to: .event) { granted, err in
                    if !granted {
                        fputs("calendar‑bridge: Calendar access not granted: \(err?.localizedDescription ?? "user denied")\n", stderr)
                        Darwin.exit(EXIT_FAILURE)
                    }
                    sema.signal()
                }
            }

            _ = sema.wait(timeout: .distantFuture)
        }
        
        // ---------- Optional: create demo event ----------
        if create {
            let demo = EKEvent(eventStore: store)
            demo.title       = "calendar‑bridge demo"
            demo.startDate   = Date().addingTimeInterval(60 * 5)   // 5 min from now
            demo.endDate     = demo.startDate.addingTimeInterval(60 * 30)
            demo.calendar    = store.defaultCalendarForNewEvents
            demo.notes       = "Created by calendar‑bridge ‑‑create"
            
            try store.save(demo, span: .thisEvent)
        }
        
        // ---------- Fetch events ----------
        let predicate = store.predicateForEvents(withStart: startDate,
                                                 end: endDate,
                                                 calendars: nil)
        let events = store.events(matching: predicate)
        
        let list: [EventDTO] = events.map { ev in
            let emails: [String] = (ev.attendees ?? [])
                .map { $0.url.absoluteString.replacingOccurrences(of: "mailto:", with: "") }
            return EventDTO(
                title: ev.title ?? "(untitled)",
                start: ev.startDate,
                end:   ev.endDate,
                location: ev.location,
                notes: ev.notes,
                attendees: emails
            )
        }
        
        // ---------- Emit JSON ----------
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let json = try encoder.encode(list)
        FileHandle.standardOutput.write(json)
        // stdout flushes automatically at process exit
    }
}

CalendarBridge.main()
