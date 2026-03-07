use std::path::PathBuf;

use librespot_core::authentication::Credentials;
use librespot_core::cache::Cache;
use librespot_core::config::SessionConfig;
use librespot_core::Session;
use librespot_oauth::OAuthClientBuilder;
use rspotify::clients::OAuthClient;
use rspotify::{AuthCodePkceSpotify, Config as RspotifyConfig};
use rspotify::Credentials as RspotifyCredentials;
use rspotify::OAuth;

const REDIRECT_URI: &str = "http://127.0.0.1:8888/callback";

const SCOPES: &[&str] = &[
    "streaming",
    "user-read-playback-state",
    "user-modify-playback-state",
    "user-read-currently-playing",
    "user-read-private",
    "user-read-email",
    "playlist-read-private",
    "playlist-read-collaborative",
    "playlist-modify-public",
    "playlist-modify-private",
    "user-library-read",
    "user-library-modify",
    "user-follow-read",
    "user-follow-modify",
    "user-read-recently-played",
    "user-top-read",
];

pub struct AuthManager {
    client_id: String,
    session: Option<Session>,
    rspotify_client: Option<AuthCodePkceSpotify>,
    cache_dir: PathBuf,
}

impl AuthManager {
    pub fn new(client_id: String) -> Self {
        let cache_dir = dirs::cache_dir()
            .unwrap_or_else(|| PathBuf::from("/tmp"))
            .join("spotti");

        Self {
            client_id,
            session: None,
            rspotify_client: None,
            cache_dir,
        }
    }

    pub async fn authenticate(&mut self) -> Result<(), AuthError> {
        // Set up librespot cache for credential persistence
        let cache = Cache::new(
            Some(self.cache_dir.join("librespot")),
            None,
            Some(self.cache_dir.join("librespot/audio")),
            None,
        ).map_err(|e| AuthError::CacheSetup(e.to_string()))?;

        let session_config = SessionConfig::default();
        let session = Session::new(session_config, Some(cache.clone()));

        // Try cached credentials first
        if let Some(cached_creds) = cache.credentials() {
            match session.connect(cached_creds, true).await {
                Ok(()) => {
                    log::info!("Connected with cached credentials");
                    self.session = Some(session);
                    self.setup_rspotify().await?;
                    return Ok(());
                }
                Err(e) => {
                    log::warn!("Cached credentials failed: {}, starting OAuth flow", e);
                }
            }
        }

        // No cached creds or they failed — run OAuth flow
        let token = self.run_oauth_flow().await?;

        let credentials = Credentials::with_access_token(&token.access_token);
        let session = Session::new(SessionConfig::default(), Some(cache));
        session
            .connect(credentials, true)
            .await
            .map_err(|e| AuthError::SessionConnect(e.to_string()))?;

        self.session = Some(session);
        self.setup_rspotify().await?;

        Ok(())
    }

    async fn run_oauth_flow(&self) -> Result<librespot_oauth::OAuthToken, AuthError> {
        let client = OAuthClientBuilder::new(&self.client_id, REDIRECT_URI, SCOPES.to_vec())
            .open_in_browser()
            .build()
            .map_err(|e| AuthError::OAuthSetup(e.to_string()))?;

        client
            .get_access_token_async()
            .await
            .map_err(|e| AuthError::OAuthToken(e.to_string()))
    }

    async fn setup_rspotify(&mut self) -> Result<(), AuthError> {
        let creds = RspotifyCredentials::new_pkce(&self.client_id);
        let oauth = OAuth {
            redirect_uri: REDIRECT_URI.to_string(),
            scopes: SCOPES.iter().map(|s| s.to_string()).collect(),
            ..Default::default()
        };
        let config = RspotifyConfig {
            token_cached: true,
            token_refreshing: true,
            cache_path: self.cache_dir.join("rspotify_token.json"),
            ..Default::default()
        };

        let mut spotify = AuthCodePkceSpotify::with_config(creds, oauth, config);

        // Try loading cached token
        if let Ok(Some(cached_token)) = spotify.read_token_cache(false).await {
            if !cached_token.is_expired() {
                *spotify.token.lock().await.expect("token mutex poisoned") = Some(cached_token);
                self.rspotify_client = Some(spotify);
                return Ok(());
            }
        }

        // No valid cached rspotify token — run CLI prompt flow
        let url = spotify
            .get_authorize_url(None)
            .map_err(|e| AuthError::OAuthSetup(e.to_string()))?;

        spotify
            .prompt_for_token(&url)
            .await
            .map_err(|e| AuthError::OAuthToken(e.to_string()))?;

        self.rspotify_client = Some(spotify);
        Ok(())
    }

    pub fn session(&self) -> Option<&Session> {
        self.session.as_ref()
    }

    pub fn rspotify(&self) -> Option<&AuthCodePkceSpotify> {
        self.rspotify_client.as_ref()
    }

    pub fn username(&self) -> Option<String> {
        self.session.as_ref().map(|s| s.username())
    }
}

#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("cache setup failed: {0}")]
    CacheSetup(String),
    #[error("OAuth setup failed: {0}")]
    OAuthSetup(String),
    #[error("OAuth token failed: {0}")]
    OAuthToken(String),
    #[error("session connect failed: {0}")]
    SessionConnect(String),
}
