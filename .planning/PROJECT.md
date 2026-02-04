# iTerm2 Remote

## What This Is

A web-based remote control for iTerm2 that lets you access your Mac's terminal sessions from any browser, anywhere. Your Mac connects to a cloud relay server, and you connect to the same server from your iPad, laptop, or phone to see and interact with all your open iTerm2 tabs as if you were sitting at your desk.

## Core Value

Full terminal experience remotely — if it works in iTerm2, it should work in the browser.

## Requirements

### Validated

(None yet — rebuild from scratch)

### Active

- [ ] Mac client connects to cloud relay and streams terminal state
- [ ] Web dashboard shows all open iTerm2 tabs
- [ ] Switch between tabs in browser
- [ ] Full terminal emulation (colors, scrollback, cursor)
- [ ] Real-time bidirectional input/output
- [ ] Session code authentication (generated on Mac, entered in browser)
- [ ] Reliable WebSocket connections with auto-reconnect
- [ ] Clean, responsive UI that works on iPad

### Out of Scope

- User accounts / multi-user — single user, session codes only
- Creating new terminal sessions from browser — view/control existing only
- Mobile native apps — web only
- Local-only mode — always uses cloud relay

## Context

**Existing codebase:** Previous implementation exists but has fundamental issues with connection stability, terminal rendering, and auth flow. This is a rebuild keeping the tech stack (SvelteKit, WebSocket, Node.js) but rewriting the implementation.

**Architecture:** Mac → Cloud Relay ← Browser. The cloud relay is a separate deployment that the user already has. This project builds both the Mac client and the web dashboard/relay server.

**Terminal emulation:** Use xterm.js for proper terminal rendering in the browser. Need to handle ANSI escape codes, colors, cursor positioning, scrollback.

**iTerm2 integration:** Use iTerm2's Python API or AppleScript to capture terminal content and inject input.

## Constraints

- **Tech stack**: SvelteKit + Node.js + WebSocket (user preference)
- **Terminal lib**: xterm.js for browser-side terminal emulation
- **Auth model**: Session codes only, no user accounts
- **Deployment**: Cloud relay on user's existing server

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Full rebuild vs incremental fix | Current implementation too buggy, easier to start fresh | — Pending |
| xterm.js for terminal | Industry standard, handles all terminal emulation complexity | — Pending |
| Session codes over passwords | Simpler than accounts, secure enough for single-user | — Pending |
| Cloud relay architecture | Avoids NAT/firewall issues, works from anywhere | — Pending |

---
*Last updated: 2026-02-04 after initialization*
