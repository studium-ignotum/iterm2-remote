# Phase 7: Web UI & Full Pipeline - Context

**Gathered:** 2026-02-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Connect the existing React/xterm.js web UI to the Rust relay server and mac-client, making end-to-end terminal access work. The web UI already exists at `relay-server-v2/web-ui/` with login page, terminal component, tab sidebar, and mobile controls. Phase 7 is about protocol integration, not UI design.

</domain>

<decisions>
## Implementation Decisions

### Protocol alignment
- Update web UI logic to match Rust relay protocol (not vice versa)
- Use `auth`/`auth_success`/`auth_failed` instead of `join`/`joined`
- All terminal I/O uses binary WebSocket frames (output, input, resize)
- Binary frame format: 1-byte session ID length prefix, then session ID bytes, then payload
- Control messages (auth, errors) remain JSON

### Session-to-tab mapping
- When new shell session connects: auto-switch to it immediately
- When shell session disconnects: show as disconnected briefly (gray out), then remove from list
- Empty state (no sessions): waiting spinner with hint message

### Build & embedding
- Build output goes directly to `relay-server-v2/assets/` (same dir relay embeds)
- Relay URL: use same-origin WebSocket (derive from window.location)
- Single `/ws` endpoint for all WebSocket connections (relay determines client type from first message)
- Build triggered via `pnpm build` in web-ui directory

### Claude's Discretion
- Session name display format (show as-is or strip PID)
- Exact disconnected state timing before removal
- Error message wording

</decisions>

<specifics>
## Specific Ideas

- Existing web UI already has: login page, terminal with xterm.js + WebGL, tab sidebar, mobile control bar, connection status indicator, reconnection logic
- Current protocol mismatch: web UI uses `join`/`joined`/`terminal_data` JSON, Rust relay uses `auth`/`auth_success` + binary frames
- Mac-client already implements length-prefixed binary frames for session ID routing (05-06 decision)

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 07-web-ui-full-pipeline*
*Context gathered: 2026-02-06*
