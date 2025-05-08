# calendar‑bridge

`calendar‑bridge` is a tiny, headless Swift CLI that provides full CRUD operations for
macOS Calendar events without user interaction. It supports both simple commands and
JSON-based operations for automation scripts. It is intended to run **locally** on
the Mac that owns the Calendar database. A Docker‑hosted micro‑service can shell‑exec
the binary and return JSON to remote callers.

---

## ✨  Features

| Action              | Details                                                                 |
|--------------------|-------------------------------------------------------------------------|
| **Read**           | Fetch every event *and recurrence* in an ISO‑8601 time range.           |
| **Create demo**    | `--create` adds a "calendar‑bridge demo" event 5 min from now.          |
| **Create JSON**    | `--createJson` creates events from JSON input with full details.        |
| **Update**         | `--updateJson` updates existing events with partial/full JSON changes.   |
| **Delete**         | `--deleteId` removes events by their unique identifier.                 |
| **JSON output**    | Title, start, end, location, notes, attendee email addresses.           |
| **Headless**       | No GUI once the user grants Calendar access the first time.             |
| **Hardened**       | Binary must be code‑signed with `--options runtime` for a stable TCC ID.|

---

## 🔨  CRUD Examples

### Read Events
```bash
calendar-bridge --start 2025-05-07T00:00:00Z --end 2025-05-08T00:00:00Z
```

### Create Event (JSON)
```bash
echo '{
  "title": "Team Meeting",
  "start": "2025-05-07T15:00:00-07:00",
  "end": "2025-05-07T16:00:00-07:00",
  "location": "Conference Room A",
  "notes": "Weekly sync"
}' | calendar-bridge --createJson
```
Create will treat timestamp as UTC. The above example is for PDT 

### Update Event (JSON)
```bash
echo '{
  "id": "EVENT-ID-HERE",
  "title": "Updated Meeting",
  "location": "Conference Room B"
}' | calendar-bridge --updateJson
```

### Delete Event
```bash
calendar-bridge --deleteId EVENT-ID-HERE
```

---

##  Requirements

* macOS 13 or newer (tested on macOS 14.4)
* Swift 5.10 toolchain (bundled with Xcode 15.4 or newer)
* A personal Apple developer account for code‑signing  
  (free tier is fine; no entitlements needed)

---

##  Build & install

```bash
git clone https://github.com/your‑org/calendar‑bridge.git
cd calendar‑bridge

# 1. Compile an optimised build
swift build -c release

# 2. Sign with hardened runtime (adjust identifier to taste)
codesign \
  -s - \
  --options runtime \
  --timestamp \
  --identifier com.clarity.calendar-bridge \
  .build/release/calendar-bridge

# 3. Move to a stable path (required for persistent TCC permission)
sudo cp .build/arm64-apple-macosx/release/calendar-bridge /usr/local/bin/

# 4. Grant Calendar permission interactively
calendar-bridge --start 2025-05-07T00:00:00Z --end 2025-05-08T00:00:00Z
# Click OK. After that, headless invocations inherit the grant.
