# calendar‑bridge

`calendar‑bridge` is a tiny, headless Swift CLI that lets automation scripts
query macOS Calendar events—or add a demo event—without user interaction.
It is intended to run **locally** on the Mac that owns the Calendar database.
A Docker‑hosted micro‑service can shell‑exec the binary and return JSON to
remote callers.

---

## ✨  Features

| Action           | Details                                                                 |
|------------------|-------------------------------------------------------------------------|
| **Read**         | Fetch every event *and recurrence* in an ISO‑8601 time range.           |
| **Create demo**  | `--create` adds a “calendar‑bridge demo” event 5 min from now.          |
| **JSON output**  | Title, start, end, location, notes, attendee email addresses.           |
| **Headless**     | No GUI once the user grants Calendar access the first time.             |
| **Hardened**     | Binary must be code‑signed with `--options runtime` for a stable TCC ID.|

---

##  Requirements

* macOS 13 or newer (tested on macOS 14.4)
* Swift 5.10 toolchain (bundled with Xcode 15.4 or newer)
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
codesign --timestamp --options runtime \
         --identifier com.clarity.calendar‑bridge \
         .build/release/calendar‑bridge

# 3. Move to a stable path (required for persistent TCC permission)
sudo cp .build/release/calendar‑bridge /usr/local/bin/
