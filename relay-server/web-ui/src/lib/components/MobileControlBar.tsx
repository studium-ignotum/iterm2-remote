/**
 * Mobile control bar — optimized for controlling coding agents on a phone.
 *
 * Design: ui-ux-pro-max design system (Terminal Remote)
 * - 44px min touch targets, 8px min spacing
 * - Semantic color-coded quick actions
 * - Command input bar (chat-style) for comfortable typing
 * - Expandable extended keys panel
 */

import { useState, useRef } from 'react';
import { useTerminal } from '../context/TerminalContext';
import './MobileControlBar.css';

interface MobileControlBarProps {
  onKey: (data: string) => void;
}

export default function MobileControlBar({ onKey }: MobileControlBarProps) {
  const [ctrlActive, setCtrlActive] = useState(false);
  const [altActive, setAltActive] = useState(false);
  const [showExtended, setShowExtended] = useState(false);
  const [inputValue, setInputValue] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);
  const { activeSessionId, getTerminal } = useTerminal();

  function scrollTerminal(lines: number) {
    if (!activeSessionId) return;
    const term = getTerminal(activeSessionId);
    term?.scrollLines(lines);
  }

  function scrollToBottom() {
    if (!activeSessionId) return;
    const term = getTerminal(activeSessionId);
    term?.scrollToBottom();
  }

  function sendKey(key: string) {
    if (ctrlActive) {
      const code = key.charCodeAt(0);
      if (key.length === 1 && code >= 65 && code <= 90) {
        onKey(String.fromCharCode(code - 64));
      } else if (key.length === 1 && code >= 97 && code <= 122) {
        onKey(String.fromCharCode(code - 96));
      } else {
        onKey(key);
      }
      setCtrlActive(false);
    } else if (altActive) {
      onKey('\x1b' + key);
      setAltActive(false);
    } else {
      onKey(key);
    }
  }

  function handleSend() {
    if (inputValue) {
      onKey(inputValue + '\r');
      setInputValue('');
    } else {
      onKey('\r');
    }
    inputRef.current?.focus();
  }

  function handleInputKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleSend();
    }
  }

  function toggleCtrl() {
    setCtrlActive((prev) => {
      if (!prev) setAltActive(false);
      return !prev;
    });
  }

  function toggleAlt() {
    setAltActive((prev) => {
      if (!prev) setCtrlActive(false);
      return !prev;
    });
  }

  return (
    <div className="mobile-bar">
      {/* Extended keys panel — toggleable */}
      {showExtended && (
        <div className="bar-row extended-row" role="toolbar" aria-label="Extended keys">
          <button className="kb" onClick={() => sendKey('\x1b')} aria-label="Escape">Esc</button>
          <button className="kb" onClick={() => sendKey('\t')} aria-label="Tab">Tab</button>
          <button
            className={`kb mod${ctrlActive ? ' on' : ''}`}
            onClick={toggleCtrl}
            aria-label="Ctrl modifier"
            aria-pressed={ctrlActive}
          >Ctrl</button>
          <button
            className={`kb mod${altActive ? ' on' : ''}`}
            onClick={toggleAlt}
            aria-label="Alt modifier"
            aria-pressed={altActive}
          >Alt</button>
          <span className="bar-sep" aria-hidden="true" />
          <button className="kb sym" onClick={() => sendKey('|')} aria-label="Pipe">|</button>
          <button className="kb sym" onClick={() => sendKey('~')} aria-label="Tilde">~</button>
          <button className="kb sym" onClick={() => sendKey('`')} aria-label="Backtick">`</button>
          <button className="kb sym" onClick={() => sendKey('/')} aria-label="Slash">/</button>
          <span className="bar-sep" aria-hidden="true" />
          <button className="kb arr" onClick={() => sendKey('\x1b[D')} aria-label="Arrow left">Left</button>
          <button className="kb arr" onClick={() => sendKey('\x1b[A')} aria-label="Arrow up">Up</button>
          <button className="kb arr" onClick={() => sendKey('\x1b[B')} aria-label="Arrow down">Down</button>
          <button className="kb arr" onClick={() => sendKey('\x1b[C')} aria-label="Arrow right">Right</button>
        </div>
      )}

      {/* Quick actions row */}
      <div className="bar-row quick-row" role="toolbar" aria-label="Quick actions">
        <button className="qb qb-yes" onClick={() => onKey('y\r')} aria-label="Yes">y</button>
        <button className="qb qb-no" onClick={() => onKey('n\r')} aria-label="No">n</button>
        <button className="qb qb-enter" onClick={() => onKey('\r')} aria-label="Enter">Enter</button>
        <button className="qb qb-cancel" onClick={() => onKey('\x03')} aria-label="Cancel">Ctrl+C</button>
        <span className="bar-sep" aria-hidden="true" />
        <button className="qb qb-scroll" onClick={() => scrollTerminal(-15)} aria-label="Page up">PgUp</button>
        <button className="qb qb-scroll" onClick={() => scrollTerminal(15)} aria-label="Page down">PgDn</button>
        <button className="qb qb-scroll" onClick={scrollToBottom} aria-label="Scroll to bottom">End</button>
        <span className="bar-sep" aria-hidden="true" />
        <button
          className={`qb qb-toggle${showExtended ? ' on' : ''}`}
          onClick={() => setShowExtended(v => !v)}
          aria-label={showExtended ? 'Hide extended keys' : 'Show extended keys'}
          aria-expanded={showExtended}
        >...</button>
      </div>

      {/* Command input row */}
      <div className="bar-row input-row">
        <input
          ref={inputRef}
          className="cmd-input"
          type="text"
          value={inputValue}
          onChange={(e) => setInputValue(e.target.value)}
          onKeyDown={handleInputKeyDown}
          placeholder="Type command..."
          autoComplete="off"
          autoCorrect="off"
          autoCapitalize="off"
          spellCheck={false}
          aria-label="Command input"
        />
        <button className="send-btn" onClick={handleSend} aria-label="Send command">
          Send
        </button>
      </div>
    </div>
  );
}
