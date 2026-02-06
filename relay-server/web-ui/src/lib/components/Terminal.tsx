/**
 * Terminal component using direct @xterm/xterm integration.
 *
 * Each instance owns a single xterm terminal for its lifetime.
 * One Terminal component is created per session — show/hide is handled
 * by the parent via CSS, so the xterm buffer is never cleared on tab switch.
 */

import { useRef, useEffect } from 'react';
import { Terminal as XTerminal, type ITerminalOptions } from '@xterm/xterm';
import '@xterm/xterm/css/xterm.css';
import { TERMINAL_RESIZE_DEBOUNCE_MS, TERMINAL_MIN_COLS, TERMINAL_MIN_ROWS } from '../../shared/constants';
import { useTerminal } from '../context/TerminalContext';
import './Terminal.css';

interface TerminalProps {
  sessionId: string;
  options?: ITerminalOptions;
  onInput?: (data: string) => void;
  onBinaryInput?: (data: string) => void;
  onTerminalResize?: (cols: number, rows: number) => void;
}

export default function Terminal({
  sessionId,
  options = {},
  onInput,
  onBinaryInput,
  onTerminalResize,
}: TerminalProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const terminalRef = useRef<XTerminal | null>(null);
  const fitAddonRef = useRef<import('@xterm/addon-fit').FitAddon | null>(null);
  const webglAddonRef = useRef<import('@xterm/addon-webgl').WebglAddon | null>(null);
  const resizeObserverRef = useRef<ResizeObserver | null>(null);
  const resizeTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const fitReadyRef = useRef(false);

  const { registerTerminal, unregisterTerminal } = useTerminal();

  // Store callbacks in refs to avoid re-running the main effect
  const onInputRef = useRef(onInput);
  const onBinaryInputRef = useRef(onBinaryInput);
  const onTerminalResizeRef = useRef(onTerminalResize);
  onInputRef.current = onInput;
  onBinaryInputRef.current = onBinaryInput;
  onTerminalResizeRef.current = onTerminalResize;

  // Create terminal ONCE on mount — never recreate on sessionId change
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const term = new XTerminal({ ...options, allowProposedApi: true });
    terminalRef.current = term;
    term.open(container);

    // Register with terminal context for message routing
    registerTerminal(sessionId, term);

    // Wire up event handlers
    const dataDisposable = term.onData((data) => onInputRef.current?.(data));
    const binaryDisposable = term.onBinary((data) => onBinaryInputRef.current?.(data));
    const resizeDisposable = term.onResize((data) => {
      console.log(`[Terminal] onResize event: cols=${data.cols}, rows=${data.rows}, minCols=${TERMINAL_MIN_COLS}, minRows=${TERMINAL_MIN_ROWS}`);
      if (data.cols >= TERMINAL_MIN_COLS && data.rows >= TERMINAL_MIN_ROWS) {
        console.log(`[Terminal] onResize: calling callback`);
        onTerminalResizeRef.current?.(data.cols, data.rows);
      }
    });

    // Load addons asynchronously
    (async () => {
      // WebGL renderer (with DOM fallback)
      try {
        const { WebglAddon } = await import('@xterm/addon-webgl');
        const webgl = new WebglAddon();
        webgl.onContextLoss(() => {
          console.warn('[Terminal] WebGL context lost, falling back to DOM renderer');
          webgl.dispose();
          webglAddonRef.current = null;
        });
        term.loadAddon(webgl);
        webglAddonRef.current = webgl;
      } catch {
        console.warn('[Terminal] WebGL not available, using DOM renderer');
      }

      // FitAddon (responsive resize)
      try {
        const { FitAddon } = await import('@xterm/addon-fit');
        const fitAddon = new FitAddon();
        term.loadAddon(fitAddon);
        fitAddonRef.current = fitAddon;
        fitReadyRef.current = true;
      } catch (e) {
        console.error('[Terminal] Failed to load FitAddon:', e);
      }

      // ClipboardAddon (OSC 52 clipboard)
      try {
        const { ClipboardAddon } = await import('@xterm/addon-clipboard');
        term.loadAddon(new ClipboardAddon());
      } catch (e) {
        console.warn('[Terminal] ClipboardAddon not available:', e);
      }

      // ImageAddon (sixel + iTerm2 inline images)
      try {
        const { ImageAddon } = await import('@xterm/addon-image');
        term.loadAddon(new ImageAddon());
      } catch (e) {
        console.warn('[Terminal] ImageAddon not available:', e);
      }

      // WebLinksAddon (clickable URLs)
      try {
        const { WebLinksAddon } = await import('@xterm/addon-web-links');
        term.loadAddon(new WebLinksAddon());
      } catch (e) {
        console.warn('[Terminal] WebLinksAddon not available:', e);
      }

      // Unicode11Addon (better unicode/emoji rendering)
      try {
        const { Unicode11Addon } = await import('@xterm/addon-unicode11');
        term.loadAddon(new Unicode11Addon());
        term.unicode.activeVersion = '11';
      } catch (e) {
        console.warn('[Terminal] Unicode11Addon not available:', e);
      }

      // Set up ResizeObserver with debounced fit
      const fitAddon = fitAddonRef.current;
      if (container && fitAddon) {
        resizeObserverRef.current = new ResizeObserver(() => {
          clearTimeout(resizeTimeoutRef.current);
          resizeTimeoutRef.current = setTimeout(() => {
            if (
              container.clientWidth > 0 &&
              container.clientHeight > 0 &&
              fitAddonRef.current
            ) {
              fitAddonRef.current.fit();
            }
          }, TERMINAL_RESIZE_DEBOUNCE_MS);
        });
        resizeObserverRef.current.observe(container);

        // Initial fit — try multiple times to ensure terminal renders properly
        const doFit = (label: string) => {
          const w = container.clientWidth;
          const h = container.clientHeight;
          console.log(`[Terminal] doFit(${label}): container=${w}x${h}, fitAddon=${!!fitAddonRef.current}, rows=${term.rows}, cols=${term.cols}`);
          if (fitAddonRef.current && w > 0 && h > 0) {
            fitAddonRef.current.fit();
            term.refresh(0, term.rows - 1);
            term.scrollToBottom();
            term.focus();
            console.log(`[Terminal] doFit(${label}): after fit rows=${term.rows}, cols=${term.cols}`);
          }
        };
        // Immediate fit attempt
        requestAnimationFrame(() => doFit('raf'));
        // Delayed fits to catch late layout (CSS transitions, flex layout settling)
        setTimeout(() => doFit('50ms'), 50);
        setTimeout(() => doFit('150ms'), 150);
        setTimeout(() => doFit('300ms'), 300);
        setTimeout(() => doFit('600ms'), 600);
        setTimeout(() => doFit('1000ms'), 1000);
      }
    })();

    // Cleanup — only on unmount
    return () => {
      clearTimeout(resizeTimeoutRef.current);
      resizeObserverRef.current?.disconnect();
      resizeObserverRef.current = null;
      webglAddonRef.current = null;
      fitAddonRef.current = null;
      dataDisposable.dispose();
      binaryDisposable.dispose();
      resizeDisposable.dispose();
      unregisterTerminal(sessionId);
      term.dispose();
      terminalRef.current = null;
    };
    // Empty deps — create terminal once on mount, destroy on unmount
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Apply option changes to existing terminal
  useEffect(() => {
    const term = terminalRef.current;
    console.log('[Terminal] options effect, term exists:', !!term, 'theme:', options.theme?.background);
    if (!term) return;

    if (options.theme) term.options.theme = options.theme;
    if (options.fontFamily !== undefined) term.options.fontFamily = options.fontFamily;
    if (options.fontSize !== undefined) term.options.fontSize = options.fontSize;
    if (options.cursorStyle !== undefined) term.options.cursorStyle = options.cursorStyle;
    if (options.cursorBlink !== undefined) term.options.cursorBlink = options.cursorBlink;
    if (options.scrollback !== undefined) term.options.scrollback = options.scrollback;

    // Force terminal to refresh with new options (if terminal has rows)
    if (term.rows > 0) {
      term.refresh(0, term.rows - 1);
    }

    console.log('[Terminal] Applied options, theme bg:', term.options.theme?.background);

    // Re-fit after option changes (font size may change dimensions)
    requestAnimationFrame(() => {
      fitAddonRef.current?.fit();
    });
  }, [options]);

  // Re-apply options after terminal fully initializes (fixes race condition on first load)
  useEffect(() => {
    const timer = setTimeout(() => {
      const term = terminalRef.current;
      if (!term) return;

      console.log('[Terminal] Delayed re-apply, theme bg:', options.theme?.background);
      if (options.theme) term.options.theme = options.theme;
      if (term.rows > 0) {
        term.refresh(0, term.rows - 1);
      }
    }, 150);
    return () => clearTimeout(timer);
  }, [options]);

  return <div ref={containerRef} className="terminal-container" />;
}
