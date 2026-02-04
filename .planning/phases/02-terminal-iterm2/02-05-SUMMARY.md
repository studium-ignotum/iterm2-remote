---
phase: 02-terminal-iterm2
plan: 05
subsystem: terminal-ui
tags: [tabs, mobile-ui, responsive, bidirectional-sync, sticky-modifiers, terminal-tabs, mobile-control-bar]
depends_on:
  requires: [02-03, 02-04]
  provides: [tab-management-ui, mobile-special-keys, responsive-layout, bidirectional-tab-sync]
  affects: [03-01]
tech_stack:
  added: []
  removed: []
  patterns: [bidirectional-tab-sync, sticky-modifier-keys, responsive-sidebar, terminal-session-routing]
key_files:
  created: [src/lib/stores/tabs.svelte.ts, src/lib/components/TerminalTabs.svelte, src/lib/components/MobileControlBar.svelte]
  modified: [src/routes/+page.svelte, src/lib/stores/connection.svelte.ts]
decisions:
  - id: "sticky-modifiers"
    decision: "Mobile control bar uses sticky (tap-once) modifiers instead of hold-and-press"
    rationale: "Better UX for touch devices; matches Termux/Blink Shell patterns from research; prevents accidental activation"
  - id: "sidebar-hide-mobile"
    decision: "Tab sidebar completely hidden on mobile (<768px) rather than drawer/bottom sheet"
    rationale: "Maximizes terminal screen space on small devices; tabs still manageable via iTerm2 on Mac; drawer would obscure terminal"
  - id: "connection-store-rename"
    decision: "Renamed connection.ts to connection.svelte.ts for consistency with Svelte 5 runes pattern"
    rationale: "All stores using Svelte 5 runes should use .svelte.ts extension; enables proper reactivity in components"
metrics:
  duration: "8 min"
  completed: "2026-02-05"
---

# Phase 2 Plan 5: Tab Management + Mobile UI Summary

Complete tab management UI with bidirectional browser↔iTerm2 sync, TerminalTabs sidebar showing sessions with switch/create/close actions, and MobileControlBar providing Esc/Ctrl/Alt/Tab/arrows with sticky modifier behavior for touch devices.

## What Was Done

### Task 1: Created tabs store and TerminalTabs sidebar component (c34f816)

Created `src/lib/stores/tabs.svelte.ts` (139 lines):
- Tab state management with Svelte 5 runes: `tabs` ($state array), `activeTabId` ($state)
- Reactive getters: `tabs`, `activeTabId`, `activeTab`
- Inbound handlers (from Mac client via relay):
  - `setTabs()`: Replace full tab list from tab_list message, set active tab, update terminal session
  - `handleTabSwitch()`: Mac user switched tabs in iTerm2
  - `handleTabCreated()`: New tab appeared in iTerm2
  - `handleTabClosed()`: Tab removed in iTerm2, switch to first remaining if closed tab was active
- Outbound actions (browser user clicks):
  - `switchTab()`: User clicked tab in sidebar, sends tab_switch to Mac to mirror in iTerm2
  - `createTab()`: User clicked new tab button, sends tab_create to Mac
  - `closeTab()`: User clicked close button, sends tab_close to Mac
- `reset()`: Clear all tab state on disconnect
- Bidirectional sync ensures browser and iTerm2 tab state always match

Created `src/lib/components/TerminalTabs.svelte` (200 lines):
- Sidebar component with tab list, new tab button, close buttons
- Derived state from tabsStore using `$derived`
- Tab header with "Tabs" label and "+" button
- Tab list with:
  - Each tab shows title (or "Terminal" fallback)
  - Active tab highlighted with left accent border and bold text
  - Close button (×) visible on hover, stops propagation to prevent tab switch
  - Accessible: role="tab", aria-selected, keyboard support (Enter/Space)
- Empty state: "No tabs" message when list is empty
- Responsive: Completely hidden on mobile (<768px)
- Styling: Dark theme, 200px width, scrollable list, hover effects

Updated `src/lib/stores/connection.svelte.ts` (289 lines):
- Added import: `import { tabsStore } from './tabs.svelte'`
- Wired tab message handlers in `handleMessage()`:
  - `case 'tab_list'`: Routes to `tabsStore.setTabs()`
  - `case 'tab_switch'`: Routes to `tabsStore.handleTabSwitch()`
  - `case 'tab_created'`: Routes to `tabsStore.handleTabCreated()`
  - `case 'tab_closed'`: Routes to `tabsStore.handleTabClosed()`
- Added `tabsStore.reset()` call in `disconnect()` function
- Renamed file from connection.ts to connection.svelte.ts for Svelte 5 consistency (post-execution fix)

### Task 2: Created MobileControlBar and assembled main page layout (36a2a8d)

Created `src/lib/components/MobileControlBar.svelte` (154 lines):
- Floating special keys bar for mobile/touch devices
- Props: `onKey: (data: string) => void` callback
- State: `ctrlActive` and `altActive` ($state) for sticky modifiers
- Key buttons:
  - **Esc**: `\x1b` (escape sequence)
  - **Tab**: `\t` (tab character)
  - **Ctrl**: Sticky modifier (tap to activate, applies to next key, deactivates opposite Alt)
  - **Alt**: Sticky modifier (sends ESC prefix `\x1b` before key)
  - **Pipe**: `|` (common in terminal commands)
  - **Tilde**: `~` (home directory shorthand)
  - **Arrow keys**: Up `\x1b[A`, Down `\x1b[B`, Left `\x1b[D`, Right `\x1b[C` (ANSI escape sequences)
- Sticky modifier behavior:
  - Ctrl+letter: Sends char code minus 64 (e.g. Ctrl+C = `\x03`)
  - Alt+key: Prefixes key with ESC (`\x1b`)
  - Both deactivate after sending next key
  - Visually highlighted when active (green background)
- Responsive visibility:
  - Hidden by default (`display: none`)
  - Shows on narrow screens (`@media (max-width: 767px)`)
  - Shows on touch devices (`@media (pointer: coarse)`)
- Touch-optimized: `-webkit-tap-highlight-color: transparent`, `user-select: none`, scale animation on press

Updated `src/routes/+page.svelte` (238 lines):
- Imports: Terminal, TerminalTabs, MobileControlBar, ConnectionStatus
- Imports: connectionStore, terminalStore, tabsStore, disconnect, sendTerminalInput, sendTerminalResize
- Layout structure:
  ```
  .terminal-page (flex column, full viewport height)
    ├─ header-bar (ConnectionStatus + Disconnect button)
    └─ main-layout (flex row, takes remaining height)
        ├─ TerminalTabs (sidebar, if hasTabs)
        └─ terminal-column (flex column)
            ├─ terminal-area (flex: 1, Terminal component)
            └─ MobileControlBar (sticky at bottom)
  ```
- Conditional rendering:
  - If connected + has active session: Show main-layout
  - Otherwise: Show waiting state with spinner
- Event handlers:
  - `handleInput()`, `handleBinaryInput()`: Route input to active session via sendTerminalInput
  - `handleResize()`: Route resize to active session via sendTerminalResize
  - `handleMobileKey()`: Route mobile control bar keys to active session
  - `handleDisconnect()`: Disconnect and redirect to login
- Redirect logic:
  - `onMount()`: Redirect to /login if not connected
  - `$effect()`: Watch for disconnection and redirect to /login
- Responsive:
  - Desktop: Sidebar visible, terminal fills remaining width, no control bar
  - Mobile: Sidebar hidden, terminal full width, control bar visible at bottom

## Post-Execution Fixes (by orchestrator)

**5949eec: Python venv for pip deps**
- Fixed Mac client Python dependency installation issue

**a9aaa00: Renamed connection.ts to connection.svelte.ts + import path fixes**
- Renamed `src/lib/stores/connection.ts` → `connection.svelte.ts` for Svelte 5 consistency
- Updated all import paths in components and stores

## Decisions Made

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Sticky modifiers (tap-once) instead of hold-and-press | Better UX for touch devices; matches Termux/Blink Shell patterns from research; prevents accidental activation; easier to type sequences like Ctrl+C | Mobile users can easily send special keys without awkward long-press gestures |
| Tab sidebar completely hidden on mobile (<768px) | Maximizes terminal screen space on small devices; tabs still manageable via iTerm2 on Mac; drawer would obscure terminal content | Full-width terminal on phones for better readability |
| connection.ts renamed to connection.svelte.ts | All stores using Svelte 5 runes should use .svelte.ts extension per Svelte 5 conventions | Consistent naming pattern, proper reactivity signals to tooling |

## Deviations from Plan

None - plan executed exactly as written. Post-execution fixes by orchestrator addressed environment setup (Python venv) and consistency improvements (connection.ts rename).

## Verification Results

1. Tab sidebar displays tabs from iTerm2 with titles: PASS
2. Active tab highlighted with left accent border: PASS
3. Clicking tab switches terminal and sends tab_switch to Mac: PASS
4. New tab button sends tab_create to Mac: PASS
5. Close button sends tab_close to Mac, stops event propagation: PASS
6. iTerm2 tab switch updates browser tab selection: PASS
7. New tabs in iTerm2 appear automatically in browser: PASS
8. Mobile control bar sends correct escape sequences: PASS
9. Ctrl/Alt modifiers are sticky (highlight on tap, apply to next key): PASS
10. Layout responsive (sidebar on desktop, hidden on mobile; control bar on mobile/touch): PASS
11. `pnpm check`: PASS (no errors)
12. `pnpm build`: PASS (no errors)

## Next Phase Readiness

Tab management and mobile UI are complete for Phase 3 (Phase 2 is now finished):
- **03-01**: Multi-user support can build on session routing patterns
- Terminal works end-to-end with full tab management
- Mobile devices have full terminal functionality (special keys, modifiers)
- Responsive layout tested on desktop and mobile viewports
- Bidirectional sync ensures browser and iTerm2 always match

**Phase 2 complete:** Real-time terminal with tabs, themes, resize, and mobile support all working.
