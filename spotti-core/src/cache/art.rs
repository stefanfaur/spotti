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

    /// Calculate total size of cached art in bytes.
    pub fn cache_size_bytes(&self) -> u64 {
        let mut total: u64 = 0;
        if let Ok(entries) = std::fs::read_dir(&self.cache_dir) {
            for entry in entries.flatten() {
                if let Ok(meta) = entry.metadata() {
                    total += meta.len();
                }
            }
        }
        total
    }

    /// Delete all cached art files.
    pub fn clear(&self) -> Result<(), ArtCacheError> {
        if let Ok(entries) = std::fs::read_dir(&self.cache_dir) {
            for entry in entries.flatten() {
                let _ = std::fs::remove_file(entry.path());
            }
        }
        Ok(())
    }

    /// Number of cached items.
    pub fn item_count(&self) -> usize {
        std::fs::read_dir(&self.cache_dir)
            .map(|entries| entries.count())
            .unwrap_or(0)
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
