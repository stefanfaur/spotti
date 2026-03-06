use std::path::PathBuf;

#[derive(Debug, thiserror::Error)]
pub enum ArtCacheError {
    #[error("download failed: {0}")]
    Download(String),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

pub struct ArtCache {
    pub(crate) cache_dir: PathBuf,
}

impl ArtCache {
    pub fn new() -> Result<Self, ArtCacheError> {
        let cache_dir = dirs::cache_dir()
            .unwrap_or_else(|| PathBuf::from("/tmp"))
            .join("spotti")
            .join("art");
        std::fs::create_dir_all(&cache_dir)?;
        Ok(Self { cache_dir })
    }

    /// Returns the local file path if cached, otherwise downloads and caches.
    pub async fn get_or_download(&self, id: &str, url: &str) -> Result<String, ArtCacheError> {
        let path = self.cache_dir.join(format!("{id}.jpg"));

        if path.exists() {
            return Ok(path.to_string_lossy().to_string());
        }

        let bytes = reqwest::get(url)
            .await
            .map_err(|e| ArtCacheError::Download(e.to_string()))?
            .bytes()
            .await
            .map_err(|e| ArtCacheError::Download(e.to_string()))?;

        tokio::fs::write(&path, &bytes).await?;

        Ok(path.to_string_lossy().to_string())
    }

    /// Check if art is already cached, return path if so
    pub fn cached_path(&self, id: &str) -> Option<String> {
        let path = self.cache_dir.join(format!("{id}.jpg"));
        if path.exists() {
            Some(path.to_string_lossy().to_string())
        } else {
            None
        }
    }
}
