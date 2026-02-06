use dashmap::DashMap;
use std::sync::Arc;
use tokio::sync::mpsc;

use crate::session::generate_session_code;

/// Message types that can be sent to browsers
#[derive(Debug, Clone)]
pub enum BrowserMessage {
    Binary(Vec<u8>),
    Text(String),
}

/// Message types that can be sent to mac-client
#[derive(Debug, Clone)]
pub enum MacMessage {
    Binary(Vec<u8>),
    Text(String),
}

/// A connected mac-client session
pub struct Session {
    pub code: String,
    pub client_id: String,
    /// Channel to send messages to the mac-client
    pub mac_tx: mpsc::Sender<MacMessage>,
    /// Connected browsers: browser_id -> sender channel
    pub browsers: DashMap<String, mpsc::Sender<BrowserMessage>>,
}

/// Shared application state
#[derive(Clone)]
pub struct AppState {
    inner: Arc<AppStateInner>,
}

struct AppStateInner {
    /// Session code -> Session data
    sessions: DashMap<String, Session>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(AppStateInner {
                sessions: DashMap::new(),
            }),
        }
    }

    /// Register a new mac-client, returns unique session code
    pub fn register_mac_client(&self, client_id: String, mac_tx: mpsc::Sender<MacMessage>) -> String {
        // Generate code with collision check
        let code = loop {
            let candidate = generate_session_code();
            if !self.inner.sessions.contains_key(&candidate) {
                break candidate;
            }
            tracing::debug!("Session code collision, regenerating");
        };

        self.inner.sessions.insert(
            code.clone(),
            Session {
                code: code.clone(),
                client_id,
                mac_tx,
                browsers: DashMap::new(),
            },
        );

        tracing::info!(code = %code, "Mac-client registered");
        code
    }

    /// Validate a session code, returns true if valid
    pub fn validate_session_code(&self, code: &str) -> bool {
        self.inner.sessions.contains_key(code)
    }

    /// Get the mac-client sender for a session code
    pub fn get_mac_sender(&self, code: &str) -> Option<mpsc::Sender<MacMessage>> {
        self.inner.sessions.get(code).map(|s| s.mac_tx.clone())
    }

    /// Remove a session (when mac-client disconnects)
    pub fn remove_session(&self, code: &str) {
        if self.inner.sessions.remove(code).is_some() {
            tracing::info!(code = %code, "Session removed");
        }
    }

    /// Get count of active sessions (for debugging)
    pub fn session_count(&self) -> usize {
        self.inner.sessions.len()
    }

    /// Add a browser to a session
    pub fn add_browser(&self, code: &str, browser_id: String, tx: mpsc::Sender<BrowserMessage>) {
        if let Some(session) = self.inner.sessions.get(code) {
            session.browsers.insert(browser_id, tx);
        }
    }

    /// Remove a browser from a session
    pub fn remove_browser(&self, code: &str, browser_id: &str) {
        if let Some(session) = self.inner.sessions.get(code) {
            session.browsers.remove(browser_id);
        }
    }

    /// Broadcast terminal output (binary) to all browsers in a session
    pub async fn broadcast_to_browsers(&self, code: &str, data: Vec<u8>) {
        if let Some(session) = self.inner.sessions.get(code) {
            for entry in session.browsers.iter() {
                let _ = entry.value().send(BrowserMessage::Binary(data.clone())).await;
            }
        }
    }

    /// Broadcast text message (JSON) to all browsers in a session
    pub async fn broadcast_text_to_browsers(&self, code: &str, text: &str) {
        if let Some(session) = self.inner.sessions.get(code) {
            for entry in session.browsers.iter() {
                let _ = entry.value().send(BrowserMessage::Text(text.to_string())).await;
            }
        }
    }

    /// Send keyboard input (binary) to mac-client
    pub async fn send_to_mac_client(&self, code: &str, data: Vec<u8>) {
        if let Some(session) = self.inner.sessions.get(code) {
            let _ = session.mac_tx.send(MacMessage::Binary(data)).await;
        }
    }

    /// Send text message (JSON) to mac-client
    pub async fn send_text_to_mac_client(&self, code: &str, text: &str) {
        if let Some(session) = self.inner.sessions.get(code) {
            let _ = session.mac_tx.send(MacMessage::Text(text.to_string())).await;
        }
    }
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}
