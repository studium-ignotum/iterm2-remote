---
phase: 02-terminal-iterm2
verified: 2026-02-05T03:15:00Z
status: gaps_found
score: 3/5 must-haves verified
gaps:
  - truth: "User can see terminal output streaming in real-time in browser"
    status: failed
    reason: "Terminal component never registers itself with terminalStore, breaking data routing"
    artifacts:
      - path: "src/lib/components/Terminal.svelte"
        issue: "Exports write() method but never calls terminalStore.registerTerminal()"
      - path: "src/routes/+page.svelte"
        issue: "Terminal component not bound to variable, cannot call registration methods"
    missing:
      - "Terminal.svelte should call terminalStore.registerTerminal() in onLoad handler"
      - "Terminal.svelte should call terminalStore.unregisterTerminal() in onDestroy"
      - "Pass activeSessionId to Terminal component to identify which session to register"
  - truth: "User can type in browser and see input appear in terminal"
    status: partial
    reason: "Input path is wired but cannot be verified without working terminal output"
    artifacts:
      - path: "src/lib/components/Terminal.svelte"
        issue: "Input capture works but output display blocked by registration gap"
    missing:
      - "Same fix as Truth 1 - terminal registration needed for bidirectional I/O"
  - truth: "Terminal resizes properly with browser window"
    status: partial
    reason: "Browser sends resize messages but Mac doesn't resize iTerm2 PTY"
    artifacts:
      - path: "mac-client/iterm-bridge.py"
        issue: "_handle_terminal_resize() logs as 'informational' but doesn't call iTerm2 resize API"
    missing:
      - "Call session size setting API in iTerm2 Python bridge (if available)"
      - "Document limitation if iTerm2 API doesn't support remote PTY resize"
---

# Phase 2: Terminal & iTerm2 Integration Verification Report

**Phase Goal:** Full terminal experience with iTerm2 tab management  
**Verified:** 2026-02-05T03:15:00Z  
**Status:** GAPS FOUND  
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can see terminal output streaming in real-time in browser | ✗ FAILED | Terminal registration missing - terminalStore.writeData() cannot route data to Terminal component |
| 2 | User can type in browser and see input appear in terminal | ⚠️ PARTIAL | Input path fully wired (Terminal.svelte → +page → sendTerminalInput → relay → Mac → iTerm2) but cannot verify without working output |
| 3 | All terminal features work correctly (colors, cursor, special keys, copy/paste) | ⚠️ BLOCKED | All features exist (6 xterm addons loaded, theme converter 112 lines, mobile keys 154 lines) but blocked by Truth 1 |
| 4 | User can view list of iTerm2 tabs in sidebar and switch between them | ✓ VERIFIED | Tab management fully wired: 3 monitor methods in Python bridge, tabs.svelte.ts 139 lines, TerminalTabs.svelte 200 lines, bidirectional sync working |
| 5 | Terminal resizes properly with browser window | ⚠️ PARTIAL | Browser sends resize (ResizeObserver + FitAddon wired), Mac receives but doesn't resize PTY (design limitation in iterm-bridge.py line 486-489) |

**Score:** 3/5 truths verified (Truth 4 fully verified, Truths 3/5 partially verified, Truths 1/2 failed/blocked)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `src/shared/protocol.ts` | Terminal & tab message schemas | ✓ VERIFIED | 10 new message types (terminal_data, terminal_input, terminal_resize, 7 tab types), substantive (313 lines total), wired to IncomingMessage/OutgoingMessage unions |
| `src/relay/server.ts` | Passthrough routing for new types | ✓ VERIFIED | Default case forwards all Zod-validated messages (line 119-126, 216-222), substantive (348 lines), properly wired |
| `mac-client/iterm-bridge.py` | iTerm2 Python API bridge | ✓ VERIFIED | 659 lines, substantive (session discovery, 3 monitors, coprocess management, config reading), properly exports all IPC message types |
| `mac-client/coprocess-bridge.sh` | PTY I/O bridge script | ✓ VERIFIED | 104 lines, substantive (socat with nc fallback, retry logic, cleanup handlers), executable |
| `mac-client/src/iterm-bridge.ts` | Node.js bridge manager | ✓ VERIFIED | 290 lines, substantive (subprocess spawn, Unix socket IPC, auto-restart, 8 methods exported), properly wired |
| `mac-client/src/session-manager.ts` | Protocol translation layer | ✓ VERIFIED | 190 lines, substantive (bidirectional IPC↔WebSocket translation, theme mapping, cursor type conversion), properly wired |
| `src/lib/components/Terminal.svelte` | xterm.js terminal component | ⚠️ ORPHANED | 210 lines, substantive (6 addons loaded, ResizeObserver, exports write/getTerminal/fit) BUT never registers with terminalStore - data routing broken |
| `src/lib/stores/terminal.svelte.ts` | Terminal state store | ⚠️ PARTIAL | 96 lines, substantive (terminal registry Map, registerTerminal/writeData methods) BUT registry never populated |
| `src/lib/iterm-theme.ts` | iTerm2 to xterm theme converter | ✓ VERIFIED | 122 lines, substantive (builds ITheme from config, maps cursor styles, fallbacks to dark theme), properly wired in connection.svelte.ts |
| `src/lib/stores/tabs.svelte.ts` | Tab state management | ✓ VERIFIED | 139 lines, substantive (8 methods for bidirectional sync), properly wired to connection store and TerminalTabs component |
| `src/lib/components/TerminalTabs.svelte` | Tab sidebar UI | ✓ VERIFIED | 200 lines, substantive (tab list, new tab button, close buttons, active indicator, keyboard support), properly wired to tabs store |
| `src/lib/components/MobileControlBar.svelte` | Mobile special keys | ✓ VERIFIED | 154 lines, substantive (11 keys, sticky Ctrl/Alt modifiers, ANSI escape sequences), properly wired to +page onKey handler |
| `src/routes/+page.svelte` | Main terminal page layout | ⚠️ PARTIAL | 238 lines, substantive (responsive layout, 5 event handlers) BUT Terminal component not bound to variable, cannot call registration |
| `src/lib/stores/connection.svelte.ts` | WebSocket connection & routing | ✓ VERIFIED | 289 lines, substantive (handles 10 message types, routes terminal_data/config/tab messages), properly wired to stores |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| iTerm2 PTY | Python bridge | coprocess-bridge.sh Unix socket | ✓ WIRED | coprocess writes to socket, Python _handle_coprocess_data reads (line 286-297) |
| Python bridge | Node.js bridge | Unix socket JSON lines | ✓ WIRED | iterm-bridge.py _send_to_client writes, iterm-bridge.ts handleMessage parses (line 149-164) |
| iterm-bridge.ts | session-manager | EventEmitter events | ✓ WIRED | bridge.on('terminal_data') → sendToRelay (line 40-46) |
| session-manager | relay | WebSocket JSON | ✓ WIRED | sendToRelay callback → ConnectionManager.send() → ws.send() |
| relay | browser | WebSocket JSON | ✓ WIRED | relay default case forwards (server.ts:119-126) → browser receives |
| connection store | terminal store | terminalStore.writeData() | ✓ WIRED | connection.svelte.ts:119 calls writeData |
| terminal store | Terminal component | terminals.get() → terminal.write() | ✗ BROKEN | Terminal never calls registerTerminal(), Map empty, write() never reached |
| Browser input | terminal component | Terminal.svelte onData prop | ✓ WIRED | onData={handleInput} in +page.svelte:86 |
| +page handleInput | sendTerminalInput | connection.svelte.ts:255-262 | ✓ WIRED | handleInput → sendTerminalInput → WebSocket |
| Mac terminal_input | iTerm2 | coprocess socket write | ✓ WIRED | Python _handle_terminal_input → writer.write (line 455-456) |
| Browser resize | FitAddon | ResizeObserver debounced fit | ✓ WIRED | Terminal.svelte:105-125 |
| Terminal onResize | sendTerminalResize | +page handleResize | ✓ WIRED | onTerminalResize={handleResize}:88 → sendTerminalResize |
| Mac terminal_resize | iTerm2 API | _handle_terminal_resize | ⚠️ NOT_CALLED | Logs as "informational", no iTerm2 API call (line 486-489) |
| iTerm2 tabs | Python bridge | FocusMonitor/LayoutChangeMonitor | ✓ WIRED | _monitor_focus (line 347-363), _monitor_layout (365-377), _enumerate_and_send_sessions (172-214) |
| tabs messages | browser tabs store | connection.svelte.ts routing | ✓ WIRED | 4 tab message types route to tabsStore (line 132-158) |
| tabs store | TerminalTabs UI | $derived reactive state | ✓ WIRED | TerminalTabs.svelte:4-6 |
| Tab click | Mac iTerm2 | tab_switch message → Python _switch_tab | ✓ WIRED | TerminalTabs click → tabs.switchTab → sendMessage → relay → Mac → tab.async_select (line 502) |

### Requirements Coverage

| Requirement | Status | Blocking Issue |
|-------------|--------|----------------|
| **TERM-01**: Terminal output streams to browser in real-time | ✗ BLOCKED | Terminal registration gap - writeData cannot route to component |
| **TERM-02**: User input in browser sends to terminal | ⚠️ PARTIAL | Input path wired but cannot verify without working output (TERM-01) |
| **TERM-03**: Full terminal emulation (colors, cursor, escape sequences) | ⚠️ BLOCKED | All features exist (6 addons, theme converter) but blocked by TERM-01 |
| **TERM-04**: Copy/paste works in browser terminal | ✓ SATISFIED | ClipboardAddon loaded (Terminal.svelte:69-75), OSC 52 support |
| **TERM-05**: Special keys work (Ctrl+C, arrows, Tab) | ✓ SATISFIED | MobileControlBar provides 11 keys with proper ANSI escape sequences |
| **TERM-06**: Terminal resizes with browser window | ⚠️ PARTIAL | Browser FitAddon + ResizeObserver work, sends resize message, but Mac doesn't resize iTerm2 PTY (design limitation) |
| **ITERM-01**: Mac client reads list of open iTerm2 tabs | ✓ SATISFIED | _enumerate_and_send_sessions discovers all tabs (line 172-214) |
| **ITERM-02**: Tab list displays in browser sidebar | ✓ SATISFIED | TerminalTabs.svelte renders tab list from tabsStore |
| **ITERM-03**: User can switch between tabs in browser | ✓ SATISFIED | Tab click → switchTab → sendMessage → Mac _switch_tab → tab.async_select |
| **ITERM-04**: Active tab indicator shows which tab is selected | ✓ SATISFIED | Left accent border, isActive flag, bold text styling (TerminalTabs.svelte:143-148) |
| **ITERM-05**: New tabs appear automatically in browser | ✓ SATISFIED | NewSessionMonitor + LayoutChangeMonitor (line 379-395, 365-377) |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| src/lib/components/Terminal.svelte | N/A | Missing lifecycle registration | 🛑 Blocker | Terminal output routing completely broken - terminalStore.writeData() cannot find terminal instance |
| src/routes/+page.svelte | 84-89 | Terminal component not bound | 🛑 Blocker | No way to call registerTerminal() from parent component |
| mac-client/iterm-bridge.py | 486-489 | Resize logged as "informational" only | ⚠️ Warning | Browser resize doesn't affect iTerm2 PTY size - design limitation or incomplete implementation |

### Human Verification Required

#### 1. Terminal Output Display (After Gap Fix)

**Test:** After fixing terminal registration, connect Mac client and browser, run `ls -la` in iTerm2  
**Expected:** Output appears immediately in browser terminal with colors and formatting  
**Why human:** Visual verification of real-time streaming, color rendering, cursor positioning

#### 2. Bidirectional Input/Output (After Gap Fix)

**Test:** Type commands in browser terminal (e.g., `echo hello`, `vim test.txt`)  
**Expected:** Commands execute in iTerm2, output appears in browser, interactive programs work  
**Why human:** End-to-end flow requires visual confirmation of both directions working

#### 3. Tab Switching Behavior

**Test:** Switch tabs in browser sidebar, verify active terminal changes and shows correct session output  
**Expected:** Switching to different tab shows different terminal session, no data mixing  
**Why human:** Multi-session state management requires human observation

#### 4. Terminal Resize End-to-End

**Test:** Resize browser window, check if iTerm2 terminal reflects new dimensions  
**Expected:** TBD - currently resize is "informational" only per design notes  
**Why human:** Visual verification needed to determine if Mac PTY actually resizes

#### 5. Mobile Special Keys

**Test:** On touch device or narrow viewport, use MobileControlBar to send Ctrl+C, arrow keys, Tab  
**Expected:** Special keys work correctly (Ctrl+C interrupts, arrows navigate, Tab completes)  
**Why human:** Touch interaction and special key behavior requires manual testing

#### 6. Copy/Paste via OSC 52

**Test:** Select text in terminal, copy (should use OSC 52), paste in external app  
**Expected:** Copied text appears in system clipboard  
**Why human:** Clipboard integration is system-level, requires manual verification

### Gaps Summary

**Critical Gap: Terminal Registration Missing**

The terminal data routing is broken end-to-end. The architecture expects:

1. Terminal component calls `terminalStore.registerTerminal(sessionId, terminal)` on mount
2. Connection store routes `terminal_data` messages via `terminalStore.writeData(sessionId, payload)`
3. Terminal store looks up terminal instance in Map and calls `terminal.write(payload)`

**Current state:**
- Terminal.svelte exports `write()`, `getTerminal()`, `fit()` methods (lines 155-171)
- Terminal.svelte NEVER calls `registerTerminal()` or `unregisterTerminal()`
- +page.svelte renders Terminal but doesn't bind it to a variable
- terminalStore.writeData() tries to look up in empty Map, write never happens

**Missing implementation:**
```typescript
// In Terminal.svelte, add to handleLoad function after terminal is set:
if (terminal && terminalStore.activeSessionId) {
  terminalStore.registerTerminal(terminalStore.activeSessionId, terminal);
}

// In Terminal.svelte onDestroy, add:
if (terminalStore.activeSessionId) {
  terminalStore.unregisterTerminal(terminalStore.activeSessionId);
}
```

**Minor Gap: Terminal Resize**

Mac client receives resize messages but doesn't resize iTerm2 PTY. Code comment suggests this is a design limitation ("iTerm2 controls the PTY size based on the session's display area"), but it's unclear if:
- iTerm2 Python API lacks remote resize capability (documented limitation)
- Implementation was deferred (TODO)
- This is acceptable behavior (resize browser terminal only, not Mac)

**Recommendation:** Document expected behavior or implement PTY resize if API supports it.

---

_Verified: 2026-02-05T03:15:00Z_  
_Verifier: Claude (gsd-verifier)_
