//
// main.swift
// calendar-bridge
//
// Headless CLI for full CRUD on macOS Calendar using EventKit.
//

import Foundation
import EventKit
import ArgumentParser

// MARK: - DTOs

struct EventDTO: Codable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let notes: String?
    let attendees: [String]
}

// MARK: - CRUD DTOs

struct NewEvent: Codable {
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let notes: String?
}

struct UpdateEvent: Codable {
    let id: String
    let title: String?
    let start: Date?
    let end: Date?
    let location: String?
    let notes: String?
}

// MARK: - CLI

struct CalendarBridge: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Fetch, create, update, or delete macOS Calendar events."
    )

    @Option(name: .customLong("start"),
            help: "Inclusive ISO-8601 start (e.g. 2025-05-07T00:00:00Z).")
    var start: String?

    @Option(name: .customLong("end"),
            help: "Exclusive ISO-8601 end (e.g. 2025-05-08T00:00:00Z).")
    var end: String?

    @Flag(name: .long, help: "Create a demo event 5 minutes from now.")
    var create: Bool = false

    @Flag(name: .long, help: "Create an event from JSON piped on stdin.")
    var createJson: Bool = false

    @Flag(name: .long, help: "Update an event from JSON piped on stdin.")
    var updateJson: Bool = false

    @Option(name: .long, help: "Delete an event by its eventIdentifier.")
    var deleteId: String?

    func run() throws {
        // Authorization
        let store = EKEventStore()
        let sema = DispatchSemaphore(value: 0)
        store.requestAccess(to: .event) { granted, error in
            if !granted {
                fputs("calendar-bridge: access to Calendar denied\n", stderr)
                Darwin.exit(EXIT_FAILURE)
            }
            sema.signal()
        }
        sema.wait()

        // DELETE
        if let id = deleteId {
            guard let ev = store.event(withIdentifier: id) else {
                fputs("calendar-bridge: no event found with id \(id)\n", stderr)
                Darwin.exit(EXIT_FAILURE)
            }
            try store.remove(ev, span: .thisEvent)
            let resp = ["success": true]
            let data = try JSONSerialization.data(withJSONObject: resp, options: [])
            FileHandle.standardOutput.write(data)
            return
        }

        // CREATE from JSON
        if createJson {
            let input = FileHandle.standardInput.readDataToEndOfFile()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let newEv = try decoder.decode(NewEvent.self, from: input)

            let ev = EKEvent(eventStore: store)
            ev.title = newEv.title
            ev.startDate = newEv.start
            ev.endDate = newEv.end
            ev.calendar = store.defaultCalendarForNewEvents
            ev.location = newEv.location
            ev.notes = newEv.notes
            try store.save(ev, span: .thisEvent)

            let resp = ["success": true, "id": ev.eventIdentifier as Any] as [String: Any]
            let data = try JSONSerialization.data(withJSONObject: resp, options: [])
            FileHandle.standardOutput.write(data)
            return
        }

        // UPDATE from JSON
        if updateJson {
            let input = FileHandle.standardInput.readDataToEndOfFile()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let upd = try decoder.decode(UpdateEvent.self, from: input)

            guard let ev = store.event(withIdentifier: upd.id) else {
                fputs("calendar-bridge: no event found with id \(upd.id)\n", stderr)
                Darwin.exit(EXIT_FAILURE)
            }
            if let t = upd.title      { ev.title = t }
            if let s = upd.start      { ev.startDate = s }
            if let e = upd.end        { ev.endDate = e }
            if let l = upd.location   { ev.location = l }
            if let n = upd.notes      { ev.notes = n }
            try store.save(ev, span: .thisEvent)

            let resp = ["success": true]
            let data = try JSONSerialization.data(withJSONObject: resp, options: [])
            FileHandle.standardOutput.write(data)
            return
        }

        // Parse dates for READ
        guard let startStr = start, let endStr = end else {
            throw ValidationError("Missing --start or --end")
        }
        func parseISO(_ s: String) -> Date? {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime]
            if let d = f1.date(from: s) { return d }
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f2.date(from: s)
        }
        guard let startDate = parseISO(startStr),
              let endDate = parseISO(endStr) else {
            throw ValidationError("Unable to parse --start/--end; use ISO-8601.")
        }
        guard startDate < endDate else {
            throw ValidationError("--start must be earlier than --end.")
        }

        // Optional: create demo event
        if create {
            let demo = EKEvent(eventStore: store)
            demo.title = "calendar-bridge demo"
            demo.startDate = Date().addingTimeInterval(60 * 5)
            demo.endDate = demo.startDate.addingTimeInterval(60 * 30)
            demo.calendar = store.defaultCalendarForNewEvents
            demo.notes = "Created by calendar-bridge --create"
            try store.save(demo, span: .thisEvent)
        }

        // FETCH events
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)
        let list: [EventDTO] = events.map { ev in
            let emails = (ev.attendees ?? []).compactMap { $0.url.absoluteString.replacingOccurrences(of: "mailto:", with: "") }
            return EventDTO(
                id: ev.eventIdentifier,
                title: ev.title ?? "(untitled)",
                start: ev.startDate,
                end: ev.endDate,
                location: ev.location,
                notes: ev.notes,
                attendees: emails
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(list)
        FileHandle.standardOutput.write(data)
    }
}

CalendarBridge.main()
