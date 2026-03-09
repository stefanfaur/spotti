use std::collections::HashMap;

use rspotify::clients::BaseClient;
use rspotify::model::idtypes::Id;
use rspotify::model::{AudioFeatures, TrackId};
use rspotify::AuthCodePkceSpotify;

use crate::player::types::TrackInfo;

/// A profile built from seed tracks, used to score recommendation candidates.
#[derive(Debug, Clone)]
pub struct SeedProfile {
    /// Tag name -> weight (higher = more seeds shared this tag)
    pub tag_weights: HashMap<String, f32>,
    pub target_tempo: f32,
    pub target_energy: f32,
    pub target_danceability: f32,
    pub target_acousticness: f32,
    pub target_valence: f32,
}

/// A candidate track with its computed score.
#[derive(Debug, Clone)]
pub struct ScoredCandidate {
    pub track: TrackInfo,
    pub score: f32,
    pub tag_score: f32,
    pub audio_score: f32,
}

/// Build a SeedProfile from seed tracks.
///
/// 1. Batch-fetches audio features for all seed track IDs from Spotify.
/// 2. Fetches artist.getTopTags for each unique seed artist (cached).
/// 3. Averages audio features into target values.
/// 4. Counts tag occurrences across seeds into tag_weights.
pub async fn build_seed_profile(
    client: &AuthCodePkceSpotify,
    seed_track_ids: &[String],
    seed_artists: &[String],
    lastfm_api_key: &str,
) -> SeedProfile {
    // 1. Fetch audio features
    let track_ids: Vec<TrackId> = seed_track_ids
        .iter()
        .filter_map(|id| TrackId::from_id_or_uri(id).ok())
        .collect();

    #[allow(deprecated)]
    let audio_features = if !track_ids.is_empty() {
        match client.tracks_features(track_ids).await {
            Ok(Some(result)) => result,
            Ok(None) => {
                log::warn!("[scoring] tracks_features returned None");
                vec![]
            }
            Err(e) => {
                log::warn!("[scoring] tracks_features failed: {}", e);
                vec![]
            }
        }
    } else {
        vec![]
    };

    // Average audio features
    let (target_tempo, target_energy, target_danceability, target_acousticness, target_valence) =
        if audio_features.is_empty() {
            (120.0, 0.5, 0.5, 0.5, 0.5)
        } else {
            let n = audio_features.len() as f32;
            let mut tempo = 0.0f32;
            let mut energy = 0.0f32;
            let mut dance = 0.0f32;
            let mut acoustic = 0.0f32;
            let mut valence = 0.0f32;
            for af in &audio_features {
                tempo += af.tempo;
                energy += af.energy;
                dance += af.danceability;
                acoustic += af.acousticness;
                valence += af.valence;
            }
            (tempo / n, energy / n, dance / n, acoustic / n, valence / n)
        };

    log::info!(
        "[scoring] audio targets: tempo={:.1} energy={:.2} dance={:.2} acoustic={:.2} valence={:.2}",
        target_tempo, target_energy, target_danceability, target_acousticness, target_valence
    );

    // 2. Fetch tags for each unique artist
    let mut tag_weights: HashMap<String, f32> = HashMap::new();
    let mut seen_artists: std::collections::HashSet<String> = std::collections::HashSet::new();

    for artist in seed_artists {
        let key = artist.to_lowercase();
        if !seen_artists.insert(key) {
            continue;
        }
        let tags = crate::spotify::track_actions::lastfm_artist_top_tags_cached(
            artist,
            lastfm_api_key,
        )
        .await;
        for tag in tags {
            *tag_weights.entry(tag).or_insert(0.0) += 1.0;
        }
    }

    log::info!("[scoring] seed profile: {} unique tags from {} artists",
        tag_weights.len(), seed_artists.len());

    SeedProfile {
        tag_weights,
        target_tempo,
        target_energy,
        target_danceability,
        target_acousticness,
        target_valence,
    }
}

/// Score a batch of candidate tracks against a seed profile.
///
/// 1. Fetches artist tags for each unique candidate artist (cached).
/// 2. Batch-fetches audio features for all candidates from Spotify.
/// 3. Computes tag_score (0-1) and audio_score (0-1) for each candidate.
/// 4. Returns candidates sorted by final score (descending).
pub async fn score_candidates(
    client: &AuthCodePkceSpotify,
    candidates: &[TrackInfo],
    profile: &SeedProfile,
    lastfm_api_key: &str,
) -> Vec<ScoredCandidate> {
    if candidates.is_empty() {
        return vec![];
    }

    // 1. Fetch artist tags for all unique candidate artists
    let mut artist_tags: HashMap<String, Vec<String>> = HashMap::new();
    for track in candidates {
        let key = track.artist.to_lowercase();
        if artist_tags.contains_key(&key) {
            continue;
        }
        let tags = crate::spotify::track_actions::lastfm_artist_top_tags_cached(
            &track.artist,
            lastfm_api_key,
        )
        .await;
        artist_tags.insert(key, tags);
    }

    // 2. Batch-fetch audio features into a lookup map by track ID
    let track_ids: Vec<TrackId> = candidates
        .iter()
        .filter_map(|t| TrackId::from_id_or_uri(&t.id).ok())
        .collect();

    let mut feature_map: HashMap<String, AudioFeatures> = HashMap::new();
    if !track_ids.is_empty() {
        // Spotify allows max 100 IDs per request; batch in chunks
        for chunk in track_ids.chunks(100) {
            #[allow(deprecated)]
            match client.tracks_features(chunk.to_vec()).await {
                Ok(Some(features)) => {
                    for f in features {
                        feature_map.insert(f.id.id().to_string(), f);
                    }
                }
                Ok(None) => {}
                Err(e) => {
                    log::warn!("[scoring] tracks_features batch failed: {}", e);
                }
            }
        }
    }

    // Compute max tag weight for normalization
    let max_tag_weight: f32 = profile.tag_weights.values().cloned().fold(0.0f32, f32::max);

    // 3. Score each candidate
    let mut scored: Vec<ScoredCandidate> = Vec::with_capacity(candidates.len());

    for track in candidates {
        // Tag score
        let artist_key = track.artist.to_lowercase();
        let candidate_tags = artist_tags.get(&artist_key).cloned().unwrap_or_default();
        let tag_score = compute_tag_score(&candidate_tags, &profile.tag_weights, max_tag_weight);

        // Audio score
        let audio_score = if let Some(af) = feature_map.get(&track.id) {
            compute_audio_score(af, profile)
        } else {
            0.5 // neutral if no features available
        };

        let final_score = 0.6 * tag_score + 0.4 * audio_score;

        scored.push(ScoredCandidate {
            track: track.clone(),
            score: final_score,
            tag_score,
            audio_score,
        });
    }

    // 4. Sort descending by score
    scored.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap_or(std::cmp::Ordering::Equal));

    if let Some(top) = scored.first() {
        log::info!("[scoring] top candidate: '{}' by '{}' score={:.3} (tag={:.3} audio={:.3})",
            top.track.title, top.track.artist, top.score, top.tag_score, top.audio_score);
    }

    scored
}

/// Compute tag overlap score (0.0 - 1.0).
/// Each matching tag contributes its seed weight; result is normalized.
fn compute_tag_score(
    candidate_tags: &[String],
    seed_weights: &HashMap<String, f32>,
    _max_weight: f32,
) -> f32 {
    if seed_weights.is_empty() || candidate_tags.is_empty() {
        return 0.0;
    }

    let mut score = 0.0f32;
    for tag in candidate_tags {
        if let Some(&weight) = seed_weights.get(tag) {
            score += weight;
        }
    }

    // Normalize: best possible score = sum of top N weights where N = candidate tag count
    let mut weights: Vec<f32> = seed_weights.values().cloned().collect();
    weights.sort_by(|a, b| b.partial_cmp(a).unwrap_or(std::cmp::Ordering::Equal));
    let max_possible: f32 = weights.iter().take(candidate_tags.len()).sum();

    if max_possible > 0.0 {
        (score / max_possible).min(1.0)
    } else {
        0.0
    }
}

/// Compute audio feature similarity score (0.0 - 1.0).
/// Uses normalized Euclidean distance inverted to similarity.
fn compute_audio_score(features: &AudioFeatures, profile: &SeedProfile) -> f32 {
    // Normalize tempo to 0-1 range (assume max ~250 BPM)
    let tempo_norm = features.tempo / 250.0;
    let target_tempo_norm = profile.target_tempo / 250.0;

    let diffs = [
        tempo_norm - target_tempo_norm,
        features.energy - profile.target_energy,
        features.danceability - profile.target_danceability,
        features.acousticness - profile.target_acousticness,
        features.valence - profile.target_valence,
    ];

    let distance: f32 = diffs.iter().map(|d| d * d).sum::<f32>().sqrt();
    // Max possible distance for 5 dimensions each in [0,1] = sqrt(5) ~= 2.236
    let max_distance = (5.0f32).sqrt();
    let similarity = 1.0 - (distance / max_distance);

    similarity.max(0.0).min(1.0)
}
