/**
 * iTerm2 Remote - Mac Client Entry Point
 *
 * Connects to the relay server, receives a session code,
 * and displays it for the user to enter in their browser.
 */

import { ConnectionManager } from './connection.js';

const RELAY_URL = process.env.RELAY_URL || 'ws://localhost:8080/mac';

console.log('iTerm2 Remote - Mac Client');
console.log('==========================');
console.log(`Connecting to relay: ${RELAY_URL}`);
console.log();

/**
 * Display session code in a prominent box.
 */
function displaySessionCode(code: string): void {
  console.log();
  console.log('+--------------------------------------+');
  console.log('|                                      |');
  console.log(`|     Session Code: ${code}          |`);
  console.log('|                                      |');
  console.log('|  Enter this code in your browser     |');
  console.log('|  to connect to this terminal.        |');
  console.log('|                                      |');
  console.log('+--------------------------------------+');
  console.log();
}

const manager = new ConnectionManager(RELAY_URL, {
  onCodeReceived: (code) => {
    displaySessionCode(code);
  },
  onStateChange: (state) => {
    // Additional state handling if needed
    if (state === 'connected') {
      console.log('[Status] Ready for browser connections');
    }
  },
  onError: (error) => {
    console.error('[Error]', error.message);
  },
});

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down...');
  manager.disconnect();
  process.exit(0);
});

process.on('SIGTERM', () => {
  manager.disconnect();
  process.exit(0);
});

// Handle uncaught errors
process.on('uncaughtException', (err) => {
  console.error('[Fatal] Uncaught exception:', err);
  manager.disconnect();
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  console.error('[Fatal] Unhandled rejection:', reason);
  manager.disconnect();
  process.exit(1);
});

// Start connection
manager.connect();
