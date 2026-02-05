---
phase: 05-mac-client
plan: 06
subsystem: ipc
tags: [unix-socket, websocket, binary-framing, bidirectional-io, async-select]

# Dependency graph
requires:
  - phase: 05-04
    provides: "Integrated IpcServer and RelayClient with event channels"
provides:
  - "Binary data send/receive for RelayClient"
  - "Stream storage and terminal data reading for IpcServer"
  - "Bidirectional data forwarding pipeline"
  - "Terminal data event types for IPC and Relay"
affects: [06-shell-integration, 07-web-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Binary frame format: 1-byte length + session_id + data"
    - "tokio::select! for multiplexed I/O in async loops"
    - "Arc<Mutex<HashMap>> for shared session state"
    - "Channel cloning for cross-module forwarding"

key-files:
  created: []
  modified:
    - "mac-client/src/relay/connection.rs"
    - "mac-client/src/ipc/mod.rs"
    - "mac-client/src/ipc/session.rs"
    - "mac-client/src/app.rs"
    - "mac-client/src/main.rs"

key-decisions:
  - "Binary frame format: 1-byte session_id length prefix enables variable-length session IDs"
  - "Clone command senders rather than pass by move for multi-consumer pattern"
  - "TerminalData events flow through UI channel for logging/debugging visibility"

patterns-established:
  - "Binary framing: length-prefix for session routing in terminal data"
  - "Bidirectional forwarding: event handlers route data to opposite module's command channel"
  - "Session lifecycle: store write half, spawn read task, cleanup on disconnect"

# Metrics
duration: 8min
completed: 2026-02-05
---

# Phase 5 Plan 06: Terminal Data Forwarding Summary

**Bidirectional terminal data pipeline between IPC shell sessions and WebSocket relay using binary framing and async select**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-05T21:40:40Z
- **Completed:** 2026-02-05T21:48:56Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- Binary data framing for terminal I/O over WebSocket
- Stream splitting with write-half storage for bidirectional IPC communication
- Async select-based multiplexing for both IpcServer and RelayClient
- Bidirectional data forwarding wired through event/command channels

## Task Commits

Each task was committed atomically:

1. **Task 1: Add terminal data events and relay binary methods** - `1cc9104` (feat)
2. **Task 2: Add stream storage and data reading to IpcServer** - `25d10ce` (feat)
3. **Task 3: Wire up bidirectional data flow** - Included in concurrent commit `cfe4818`

## Files Created/Modified
- `mac-client/src/app.rs` - UiEvent::TerminalDataFromShell/Relay, BackgroundCommand::SendTerminalData/SendToShell
- `mac-client/src/relay/connection.rs` - send_terminal_data(), handle_binary_message(), RelayCommand/RelayEvent::TerminalData
- `mac-client/src/relay/mod.rs` - Export RelayCommand
- `mac-client/src/ipc/mod.rs` - IpcCommand::WriteToSession, IpcEvent::TerminalData, read_terminal_data(), Arc<Mutex<HashMap>>
- `mac-client/src/ipc/session.rs` - OwnedWriteHalf storage, Session.write()
- `mac-client/src/main.rs` - Command channel creation, forwarding function updates

## Decisions Made
- **Binary frame format**: 1-byte length prefix + session_id bytes + terminal data. Enables variable-length session IDs while keeping framing simple.
- **Arc<Mutex<HashMap>> for sessions**: Allows shared mutable access from both connection handler and command processor.
- **Clone command senders**: Forward functions need their own copy of command senders to route data to opposite module.
- **TerminalData through UI channel**: Even though data is forwarded directly, events go to UI for logging/debugging visibility.

## Deviations from Plan

None - plan executed as specified.

## Issues Encountered
- Task 3 changes were included in a concurrent commit from plan 05-05 due to file modification during editing. The functionality is complete and correct, just committed under a different plan's metadata.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Terminal data pipeline complete: shell -> IPC -> relay -> browser and reverse
- Ready for Phase 6: Shell integration scripts can now connect and exchange terminal data
- Ready for Phase 7: Web UI can receive and display terminal output

---
*Phase: 05-mac-client*
*Completed: 2026-02-05*
