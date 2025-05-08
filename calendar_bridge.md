calendar‑bridge is a lightweight, headless command‑line utility that lets a Docker‑hosted micro‑service read and, optionally, create macOS Calendar events without user interaction. The signed Swift binary lives on the host Mac (or a dedicated, signed‑in Mac mini), where it has once‑off, full‑access permission granted by the user through the standard Transparency, Consent & Control (TCC) prompt. When invoked, the tool:

1. Instantiates EKEventStore, blocking until EventKit confirms authorisation.  
2. Parses `--start` and `--end` ISO‑8601 flags (plus an optional `--create` flag).  
3. Builds an EventKit predicate, fetches every event and recurrence in that range, and marshals the title, start/end, location, notes and attendee email addresses into a JSON array printed to stdout.  
4. If `--create` is present, inserts a sample event and saves it with `eventStore.save(_:span:)`.

The surrounding Docker container is a minimal Linux image that exposes an HTTP endpoint. It bind‑mounts `/usr/local/bin/calendar‑bridge` from the host and simply shell‑execs the binary, returning the JSON through the API. Because the executable’s code signature and path stay constant, the TCC grant persists across restarts and container rebuilds. Moving the binary or re‑signing it would require the user to grant permission again, but normal updates to the shim do not.

This design keeps Apple‑only code out of the container image, relies on a single, stable consent flow, and delivers calendar data to any local or tunneled HTTP client on demand.