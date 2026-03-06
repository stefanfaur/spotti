use rspotify::clients::OAuthClient;
use rspotify::AuthCodePkceSpotify;
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct DeviceInfo {
    pub id: Option<String>,
    pub name: String,
    pub device_type: String,
    pub is_active: bool,
    pub volume_percent: Option<u32>,
}

pub async fn fetch_devices(
    client: &AuthCodePkceSpotify,
) -> Result<Vec<DeviceInfo>, rspotify::ClientError> {
    let devices = client.device().await?;
    Ok(devices
        .into_iter()
        .map(|d| DeviceInfo {
            id: d.id,
            name: d.name,
            device_type: format!("{:?}", d._type),
            is_active: d.is_active,
            volume_percent: d.volume_percent,
        })
        .collect())
}

pub async fn transfer_playback(
    client: &AuthCodePkceSpotify,
    device_id: &str,
    start_playing: bool,
) -> Result<(), rspotify::ClientError> {
    client
        .transfer_playback(device_id, Some(start_playing))
        .await
}
