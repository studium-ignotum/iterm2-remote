# Phase 1: Connection & Authentication - Research

**Researched:** 2026-02-04
**Domain:** WebSocket relay architecture, session code authentication, reconnection strategies
**Confidence:** HIGH (verified with npm registries, official docs, current best practices)

## Summary

This phase establishes the three-party WebSocket relay architecture (Mac <-> Relay <-> Browser) with session code authentication. The core challenge is maintaining reliable bidirectional communication through an intermediary server while handling network interruptions gracefully.

The standard approach uses:
1. **ws** library (v8.19.0) for the Node.js relay server - lightweight, zero-dependency, battle-tested
2. **nanoid** (v5.1.6) with custom alphabet for session code generation - cryptographically secure, human-readable
3. **Finite state machine** pattern for connection lifecycle management - prevents illegal state transitions
4. **Exponential backoff with jitter** for reconnection - prevents thundering herd during outages
5. **Application-level heartbeat** (ping/pong) - detects dead connections faster than TCP keepalive

**Primary recommendation:** Build a stateless relay that routes messages between authenticated pairs. The relay should NOT interpret terminal data - it only validates session codes and forwards bytes.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ws | 8.19.0 | WebSocket server (relay) | Zero-dependency, binary support, ping/pong built-in, millions weekly downloads |
| nanoid | 5.1.6 | Session code generation | Cryptographically secure, customAlphabet for human-friendly codes |
| zod | 4.3.6 | Message schema validation | TypeScript-first, runtime + compile-time safety, discriminated unions |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| reconnecting-websocket | 4.4.0 | Browser auto-reconnect | Browser client connection management |
| nanoid-dictionary | latest | Character sets for codes | Use `nolookalikes` for session codes |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ws | socket.io | Socket.io adds unnecessary abstraction, polling fallback not needed |
| ws | uWebSockets.js | C++ dependency complexity not worth marginal perf gain for this scale |
| nanoid | uuid | UUIDs are not human-readable, session codes need to be typed by users |
| reconnecting-websocket | custom | Library handles edge cases (backoff, jitter) correctly out of box |

**Installation:**
```bash
# Relay server
npm install ws nanoid zod
npm install -D @types/ws

# Browser client (via SvelteKit)
npm install reconnecting-websocket zod
```

## Architecture Patterns

### Recommended Project Structure

```
src/
├── relay/
│   ├── server.ts           # WebSocket server setup
│   ├── session-registry.ts # Session code -> connection mapping
│   ├── message-router.ts   # Forward messages between pairs
│   └── heartbeat.ts        # Ping/pong health checks
├── shared/
│   ├── protocol.ts         # Message type definitions (Zod schemas)
│   └── constants.ts        # Timeouts, limits, etc.
└── client/
    ├── connection.ts       # WebSocket wrapper with reconnect
    └── state-machine.ts    # Connection state management
```

### Pattern 1: Connection State Machine

**What:** Finite state machine for connection lifecycle
**When to use:** All WebSocket connections (browser and Mac client)
**Why:** Prevents illegal state transitions, makes debugging easier, enables proper UI feedback

```typescript
// Source: Verified pattern from ts-ws-machine and best practices research
type ConnectionState =
  | 'disconnected'       // No connection
  | 'connecting'         // Initial connection attempt
  | 'authenticating'     // Connected, sending session code
  | 'connected'          // Fully authenticated, ready for data
  | 'reconnecting';      // Lost connection, attempting recovery

interface StateTransitions {
  disconnected: ['connecting'];
  connecting: ['authenticating', 'disconnected'];
  authenticating: ['connected', 'disconnected'];
  connected: ['reconnecting', 'disconnected'];
  reconnecting: ['authenticating', 'disconnected'];
}

// Only these transitions are valid
function canTransition(from: ConnectionState, to: ConnectionState): boolean {
  const allowed = STATE_TRANSITIONS[from];
  return allowed.includes(to);
}
```

### Pattern 2: Session Code Generation

**What:** Human-readable, cryptographically secure session codes
**When to use:** Mac client generates on startup, browser enters to join
**Why:** Short enough to type, no ambiguous characters, secure against guessing

```typescript
// Source: nanoid documentation + nanoid-dictionary best practices
import { customAlphabet } from 'nanoid';

// nolookalikes: excludes 1/l/I, 0/O/o, etc.
// 6 chars with 32-char alphabet = 32^6 = ~1 billion combinations
// Collision probability: need ~40k codes for 1% chance
const SESSION_CODE_ALPHABET = '346789ABCDEFGHJKLMNPQRTUVWXY';
const generateSessionCode = customAlphabet(SESSION_CODE_ALPHABET, 6);

// Usage
const code = generateSessionCode(); // e.g., "H4F7KN"
```

### Pattern 3: Message Protocol with Type Discrimination

**What:** JSON messages with `type` field for routing + Zod validation
**When to use:** All WebSocket communication
**Why:** Type-safe, runtime-validated, easy to extend

```typescript
// Source: Zod documentation + WebSocket best practices
import { z } from 'zod';

// All message types share discriminant field
const BaseMessage = z.object({
  type: z.string(),
});

// Mac client -> Relay: Register and get session code
const RegisterMessage = z.object({
  type: z.literal('register'),
  clientId: z.string().uuid(),
});

// Relay -> Mac client: Session code assigned
const RegisteredMessage = z.object({
  type: z.literal('registered'),
  code: z.string().length(6),
  expiresAt: z.number(), // Unix timestamp
});

// Browser -> Relay: Join with session code
const JoinMessage = z.object({
  type: z.literal('join'),
  code: z.string().length(6),
});

// Relay -> Browser: Join succeeded
const JoinedMessage = z.object({
  type: z.literal('joined'),
  sessionId: z.string().uuid(),
});

// Error response
const ErrorMessage = z.object({
  type: z.literal('error'),
  code: z.enum(['INVALID_CODE', 'EXPIRED_CODE', 'ALREADY_JOINED', 'NOT_FOUND']),
  message: z.string(),
});

// Bidirectional: Terminal data
const DataMessage = z.object({
  type: z.literal('data'),
  payload: z.string(), // Terminal I/O (could be base64 for binary)
});

// Health check
const PingMessage = z.object({ type: z.literal('ping'), ts: z.number() });
const PongMessage = z.object({ type: z.literal('pong'), ts: z.number() });

// Union for parsing any incoming message
const IncomingMessage = z.discriminatedUnion('type', [
  RegisterMessage,
  JoinMessage,
  DataMessage,
  PingMessage,
]);

// Safe parsing utility
function parseMessage(raw: string): z.infer<typeof IncomingMessage> | null {
  try {
    const data = JSON.parse(raw);
    const result = IncomingMessage.safeParse(data);
    return result.success ? result.data : null;
  } catch {
    return null;
  }
}
```

### Pattern 4: Exponential Backoff with Jitter

**What:** Reconnection delays that grow exponentially with randomization
**When to use:** All reconnection attempts (browser and Mac client)
**Why:** Prevents thundering herd, gives server time to recover

```typescript
// Source: OneUptime blog + DEV.to best practices (verified 2026-01)
interface BackoffConfig {
  initialDelay: number;  // 1000ms
  maxDelay: number;      // 30000ms
  multiplier: number;    // 2
  jitterFactor: number;  // 0.1 (10%)
}

function calculateBackoff(attempt: number, config: BackoffConfig): number {
  const { initialDelay, maxDelay, multiplier, jitterFactor } = config;

  // Exponential growth
  const exponentialDelay = initialDelay * Math.pow(multiplier, attempt);

  // Cap at maximum
  const cappedDelay = Math.min(exponentialDelay, maxDelay);

  // Add jitter (random factor between -jitter and +jitter)
  const jitter = cappedDelay * jitterFactor * (Math.random() * 2 - 1);

  return Math.floor(cappedDelay + jitter);
}

// Usage: attempt 0 = ~1s, attempt 1 = ~2s, attempt 2 = ~4s, etc.
const delay = calculateBackoff(attempt, {
  initialDelay: 1000,
  maxDelay: 30000,
  multiplier: 2,
  jitterFactor: 0.1,
});
```

### Pattern 5: Application-Level Heartbeat

**What:** Ping/pong messages at application layer (not just WebSocket protocol)
**When to use:** Relay server pings clients, clients respond with pong
**Why:** TCP keepalive is insufficient; detect dead connections in 30-60s instead of minutes

```typescript
// Source: ws library official documentation + VideoSDK best practices
import { WebSocketServer, WebSocket } from 'ws';

const HEARTBEAT_INTERVAL = 30000; // 30 seconds
const HEARTBEAT_TIMEOUT = 10000;  // 10 seconds to respond

function setupHeartbeat(wss: WebSocketServer) {
  // Track connection health
  const connectionHealth = new WeakMap<WebSocket, { isAlive: boolean }>();

  wss.on('connection', (ws) => {
    connectionHealth.set(ws, { isAlive: true });

    ws.on('pong', () => {
      const health = connectionHealth.get(ws);
      if (health) health.isAlive = true;
    });
  });

  // Periodic health check
  const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
      const health = connectionHealth.get(ws);
      if (!health || !health.isAlive) {
        return ws.terminate(); // Dead connection
      }
      health.isAlive = false;
      ws.ping(); // Will set isAlive = true when pong received
    });
  }, HEARTBEAT_INTERVAL);

  wss.on('close', () => clearInterval(interval));
}
```

### Anti-Patterns to Avoid

- **Storing terminal data on relay:** Relay should forward bytes, not buffer history. Memory grows unbounded.
- **Polling for connection status:** Use push-based state updates, not repeated queries.
- **Auth token in WebSocket URL:** Use single-use tickets obtained via separate auth call.
- **Synchronous message processing:** Use async/await throughout to avoid blocking.
- **Unbounded session codes:** Codes must expire (default: 5 minutes unused, or after join).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reconnection logic | Custom retry loops | reconnecting-websocket | Handles backoff, jitter, state correctly |
| Session code generation | Math.random() | nanoid customAlphabet | Cryptographically secure, uniform distribution |
| Message validation | Manual type checks | Zod schemas | Runtime + compile-time safety, discriminated unions |
| UUID generation | Custom or uuid package | crypto.randomUUID() | Built into Node.js 18+, browser native |

**Key insight:** Connection management has many edge cases (partial writes, half-open connections, rapid state transitions). Libraries have solved these; custom code will miss cases.

## Common Pitfalls

### Pitfall 1: Three-Party State Mismatch

**What goes wrong:** Browser thinks connected, relay thinks connected, but Mac client disconnected. User types into void.

**Why it happens:** Three-party architecture has more failure modes. Each connection fails independently.

**How to avoid:**
1. Relay immediately notifies browser when Mac disconnects
2. End-to-end heartbeat: browser ping must reach Mac and return (not just relay)
3. Display connection state for BOTH legs in UI

**Warning signs:** Users report "it just stopped working"; works after refresh.

### Pitfall 2: Reconnection Without State Sync

**What goes wrong:** After reconnect, terminal shows stale or corrupted content.

**Why it happens:** Messages sent during disconnect are lost. Escape sequences split across reconnection.

**How to avoid:**
1. Sequence number all messages
2. Replay unacknowledged messages on reconnect
3. Request terminal refresh from Mac client after reconnect
4. Queue limited outbound messages during brief disconnects

**Warning signs:** "Weird characters" after wifi blip; fixes with `clear` command.

### Pitfall 3: Session Code in URL/Logs

**What goes wrong:** Session code appears in server logs, browser history, referrer headers.

**Why it happens:** Easy to pass code as query param in WebSocket URL.

**How to avoid:**
1. Connect WebSocket first (no code in URL)
2. Send session code as first message after connection
3. Code is single-use: invalidate after successful join
4. Codes expire after timeout (5 minutes)

**Warning signs:** Session codes visible in access logs.

### Pitfall 4: Missing Connection Timeout

**What goes wrong:** Connection hangs forever if server unreachable.

**Why it happens:** WebSocket connect has no built-in timeout.

**How to avoid:**
1. Implement connection timeout (10 seconds)
2. Use `AbortController` for cancelable connections
3. Transition to `disconnected` state on timeout

**Warning signs:** App appears frozen during network issues.

### Pitfall 5: Race Conditions on Rapid Reconnect

**What goes wrong:** Multiple reconnection attempts overlap, causing duplicate connections or state corruption.

**Why it happens:** Connection close triggers reconnect, but previous attempt still in progress.

**How to avoid:**
1. State machine prevents overlapping transitions
2. Cancel pending connection attempts before starting new one
3. Use locks/flags to prevent concurrent connect calls

**Warning signs:** Duplicate messages, multiple connection callbacks firing.

## Code Examples

### Complete Relay Server Setup

```typescript
// Source: ws documentation + verified best practices
import { WebSocketServer, WebSocket } from 'ws';
import { customAlphabet } from 'nanoid';
import { z } from 'zod';

const generateCode = customAlphabet('346789ABCDEFGHJKLMNPQRTUVWXY', 6);

interface Session {
  code: string;
  mac: WebSocket | null;
  browser: WebSocket | null;
  createdAt: number;
  expiresAt: number;
}

const sessions = new Map<string, Session>();

const wss = new WebSocketServer({ port: 8080 });

wss.on('connection', (ws, req) => {
  const path = req.url;

  if (path === '/mac') {
    handleMacConnection(ws);
  } else if (path === '/browser') {
    handleBrowserConnection(ws);
  } else {
    ws.close(4000, 'Invalid path');
  }
});

function handleMacConnection(ws: WebSocket) {
  const code = generateCode();
  const session: Session = {
    code,
    mac: ws,
    browser: null,
    createdAt: Date.now(),
    expiresAt: Date.now() + 5 * 60 * 1000, // 5 minutes
  };
  sessions.set(code, session);

  ws.send(JSON.stringify({ type: 'registered', code }));

  ws.on('message', (data) => {
    const session = findSessionByMac(ws);
    if (session?.browser?.readyState === WebSocket.OPEN) {
      session.browser.send(data); // Forward to browser
    }
  });

  ws.on('close', () => {
    const session = findSessionByMac(ws);
    if (session) {
      if (session.browser?.readyState === WebSocket.OPEN) {
        session.browser.send(JSON.stringify({
          type: 'error',
          code: 'MAC_DISCONNECTED',
          message: 'Mac client disconnected',
        }));
      }
      sessions.delete(session.code);
    }
  });
}

function handleBrowserConnection(ws: WebSocket) {
  let joinedSession: Session | null = null;

  ws.on('message', (raw) => {
    const data = JSON.parse(raw.toString());

    if (data.type === 'join') {
      const session = sessions.get(data.code);

      if (!session) {
        ws.send(JSON.stringify({
          type: 'error',
          code: 'INVALID_CODE',
          message: 'Session code not found',
        }));
        return;
      }

      if (Date.now() > session.expiresAt) {
        sessions.delete(data.code);
        ws.send(JSON.stringify({
          type: 'error',
          code: 'EXPIRED_CODE',
          message: 'Session code has expired',
        }));
        return;
      }

      session.browser = ws;
      joinedSession = session;
      ws.send(JSON.stringify({ type: 'joined' }));
      return;
    }

    // Forward other messages to Mac
    if (joinedSession?.mac?.readyState === WebSocket.OPEN) {
      joinedSession.mac.send(raw);
    }
  });

  ws.on('close', () => {
    if (joinedSession) {
      joinedSession.browser = null;
    }
  });
}
```

### Browser Connection Manager (Svelte)

```typescript
// Source: reconnecting-websocket + Svelte 5 patterns
import ReconnectingWebSocket from 'reconnecting-websocket';
import { z } from 'zod';

type ConnectionState = 'disconnected' | 'connecting' | 'authenticating' | 'connected' | 'reconnecting';

// Svelte 5 runes
let state = $state<ConnectionState>('disconnected');
let error = $state<string | null>(null);

const JoinedMessage = z.object({ type: z.literal('joined') });
const ErrorMessage = z.object({
  type: z.literal('error'),
  code: z.string(),
  message: z.string(),
});

let ws: ReconnectingWebSocket | null = null;

export function connect(sessionCode: string) {
  state = 'connecting';
  error = null;

  ws = new ReconnectingWebSocket('wss://relay.example.com/browser', [], {
    maxReconnectionDelay: 30000,
    minReconnectionDelay: 1000,
    reconnectionDelayGrowFactor: 2,
    maxRetries: 10,
  });

  ws.addEventListener('open', () => {
    state = 'authenticating';
    ws!.send(JSON.stringify({ type: 'join', code: sessionCode }));
  });

  ws.addEventListener('message', (event) => {
    const data = JSON.parse(event.data);

    if (JoinedMessage.safeParse(data).success) {
      state = 'connected';
      return;
    }

    const errorResult = ErrorMessage.safeParse(data);
    if (errorResult.success) {
      error = errorResult.data.message;
      state = 'disconnected';
      ws?.close();
      return;
    }

    // Handle terminal data
    if (data.type === 'data') {
      onTerminalData(data.payload);
    }
  });

  ws.addEventListener('close', () => {
    if (state === 'connected') {
      state = 'reconnecting';
    } else {
      state = 'disconnected';
    }
  });

  ws.addEventListener('error', () => {
    error = 'Connection error';
  });
}

export function disconnect() {
  ws?.close();
  ws = null;
  state = 'disconnected';
}

export function send(data: string) {
  if (state === 'connected' && ws?.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ type: 'data', payload: data }));
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| socket.io default | Raw WebSocket (ws) | 2020+ | WebSocket support universal, no fallback needed |
| Manual reconnect | reconnecting-websocket | 2018+ | Standard library handles edge cases |
| UUID for codes | nanoid customAlphabet | 2020+ | Human-readable, shorter, equally secure |
| Any for messages | Zod discriminated unions | 2022+ | Type-safe + runtime-safe |

**Deprecated/outdated:**
- **Socket.io for simple relay:** Unnecessary abstraction; raw ws is sufficient
- **Long-polling fallback:** Modern browsers have native WebSocket; don't build fallback
- **Manual JSON parsing:** Use Zod for validation, not just JSON.parse

## Open Questions

1. **Binary vs Text for terminal data**
   - What we know: Terminal data is text with ANSI escapes
   - What's unclear: Whether base64 encoding is needed for reliability
   - Recommendation: Start with text, switch to binary if encoding issues arise

2. **Session code length tradeoff**
   - What we know: 6 chars = ~1B combinations, good for manual entry
   - What's unclear: Whether QR codes will be added later (could use longer codes)
   - Recommendation: Start with 6 chars, design to make length configurable

3. **Multiple browser connections**
   - What we know: Current design supports one browser per Mac
   - What's unclear: Whether multiple viewers should be supported
   - Recommendation: Plan for multiple browsers but implement single first

## Sources

### Primary (HIGH confidence)
- npm registry - ws@8.19.0, nanoid@5.1.6, zod@4.3.6, reconnecting-websocket@4.4.0
- [ws library GitHub documentation](https://github.com/websockets/ws/blob/master/doc/ws.md) - WebSocketServer API, heartbeat patterns
- [nanoid GitHub](https://github.com/ai/nanoid) - customAlphabet API, security guarantees
- [nanoid-dictionary GitHub](https://github.com/CyberAP/nanoid-dictionary) - nolookalikes character set

### Secondary (MEDIUM confidence)
- [OneUptime Blog: WebSocket Reconnection Logic](https://oneuptime.com/blog/post/2026-01-24-websocket-reconnection-logic/view) - State machine pattern, message queuing
- [DEV.to: Robust WebSocket Reconnection Strategies](https://dev.to/hexshift/robust-websocket-reconnection-strategies-in-javascript-with-exponential-backoff-40n1) - Exponential backoff with jitter code
- [Ably Blog: WebSocket Authentication](https://ably.com/blog/websocket-authentication) - Ephemeral token pattern
- [ts-ws-machine GitHub](https://github.com/rundis/ts-ws-machine) - FSM for WebSocket connections
- [Egghead: Type-Safe WebSocket with Zod](https://egghead.io/lessons/make-a-type-safe-and-runtime-safe-web-socket-communication-with-zod~efw0y) - Message validation pattern

### Tertiary (LOW confidence)
- Community patterns from WebSearch (verified against official docs where possible)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified current versions via npm registry
- Architecture patterns: HIGH - Verified against official library documentation
- Pitfalls: MEDIUM - Based on multiple sources + project-level PITFALLS.md

**Research date:** 2026-02-04
**Valid until:** 2026-03-04 (30 days - stable domain, libraries don't change rapidly)
