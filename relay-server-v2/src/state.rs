use dashmap::DashMap;
use std::sync::Arc;
use tokio::sync::mpsc;

use crate::session::generate_session_code;

/// A connected mac-client session
pub struct Session {
    pub code: String,
    pub client_id: String,
    /// Channel to send messages to the mac-client
    pub mac_tx: mpsc::Sender<Vec<u8>>,
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
    pub fn register_mac_client(&self, client_id: String, mac_tx: mpsc::Sender<Vec<u8>>) -> String {
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
    pub fn get_mac_sender(&self, code: &str) -> Option<mpsc::Sender<Vec<u8>>> {
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
}

impl Default for AppState {
    fn default() -> Self {
        Self::new()
    }
}
