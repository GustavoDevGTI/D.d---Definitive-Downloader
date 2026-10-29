// Isolated research harness; never linked into the Flutter application.
use std::{env, io, time::Duration};
use librespot::{
    core::{authentication::Credentials, config::SessionConfig, session::Session, spotify_id::SpotifyId, SpotifyUri},
    metadata::{Metadata, Track},
    playback::{audio_backend, config::{AudioFormat, PlayerConfig}, mixer::NoOpVolume, player::{Player, PlayerEvent}},
};

struct SafeDiagnostics;
static DIAGNOSTICS: SafeDiagnostics = SafeDiagnostics;
impl log::Log for SafeDiagnostics {
    fn enabled(&self, metadata: &log::Metadata) -> bool { metadata.level() <= log::Level::Warn }
    fn log(&self, record: &log::Record) {
        if self.enabled(record.metadata()) {
            let file = std::path::Path::new(record.file().unwrap_or("unknown")).file_name().unwrap().to_string_lossy();
            // Source location only. Formatted upstream messages may contain secrets.
            println!("{{\"stage\":\"native_log\",\"level\":\"{}\",\"file\":\"{}\",\"line\":{}}}", record.level(), file, record.line().unwrap_or(0));
        }
    }
    fn flush(&self) {}
}

#[tokio::main]
async fn main() {
    log::set_logger(&DIAGNOSTICS).unwrap();
    log::set_max_level(log::LevelFilter::Warn);
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 { std::process::exit(2); }
    // Secret enters only through the parent's anonymous stdin pipe.
    let mut secret = String::new();
    if io::stdin().read_line(&mut secret).is_err() || secret.len() > 16384 { return; }
    let credentials = Credentials::with_access_token(secret.trim());
    drop(secret);
    let session = Session::new(SessionConfig::default(), None);
    match tokio::time::timeout(Duration::from_secs(35), session.connect(credentials, false)).await {
        Ok(Ok(())) => println!("SESSION_OK"),
        Ok(Err(error)) => { println!("SESSION_ERROR:{:?}", error.kind); return; }
        Err(_) => { println!("SESSION_TIMEOUT"); return; }
    }
    match tokio::time::timeout(Duration::from_secs(35), session.spclient().client_token()).await {
        Ok(Ok(_)) => println!("SESSION_CLIENT_TOKEN_OK"),
        Ok(Err(error)) => { println!("SESSION_CLIENT_TOKEN_ERROR:{:?}", error.kind); session.shutdown(); return; },
        Err(_) => { println!("SESSION_CLIENT_TOKEN_TIMEOUT"); session.shutdown(); return; }
    }
    match tokio::time::timeout(Duration::from_secs(35), session.login5().auth_token()).await {
        Ok(Ok(_)) => println!("SESSION_LOGIN5_OK"),
        Ok(Err(error)) => { println!("SESSION_LOGIN5_ERROR:{:?}", error.kind); session.shutdown(); return; },
        Err(_) => { println!("SESSION_LOGIN5_TIMEOUT"); session.shutdown(); return; }
    }
    let track = SpotifyUri::Track { id: SpotifyId::from_base62(&args[1]).unwrap() };
    let duration = match tokio::time::timeout(Duration::from_secs(40), Track::get(&session, &track)).await {
        Ok(Ok(metadata)) => { println!("METADATA_OK:{}", metadata.duration); metadata.duration },
        Ok(Err(error)) => {
            println!("METADATA_ERROR:{:?}", error.kind);
            let reason = error.error.to_string();
            // Enum/static messages only, never remote response bodies or credentials.
            if reason.starts_with("Login request was denied:") {
                println!("METADATA_LOGIN5_DENIED");
            } else if reason == "No client token response type" {
                println!("METADATA_CLIENT_TOKEN_EMPTY");
            } else if reason == "Couldn't successfully authenticate after 3 times" {
                println!("METADATA_LOGIN5_RETRIES_FAILED");
            }
            if let Some(cause) = error.error.downcast_ref::<librespot::core::spclient::SpClientError>() {
                match cause {
                    librespot::core::spclient::SpClientError::ExpectedEntry(entry) => println!("METADATA_MISSING:{entry}"),
                    librespot::core::spclient::SpClientError::NoData => println!("METADATA_EMPTY"),
                    _ => println!("METADATA_ATTRIBUTE_MISSING"),
                }
            }
            session.shutdown(); return;
        }
        Err(_) => { println!("METADATA_TIMEOUT"); session.shutdown(); return; }
    };
    let backend = audio_backend::find(Some("pipe".to_owned())).unwrap();
    let output = args[2].clone();
    let player = Player::new(PlayerConfig::default(), session.clone(), Box::new(NoOpVolume), move || {
        backend(Some(output.clone()), AudioFormat::F32)
    });
    let mut events = player.get_player_event_channel();
    player.load(track, true, 0);
    let outcome = tokio::time::timeout(Duration::from_millis((duration.max(0) as u64 + 60000).min(420000)), async {
        while let Some(event) = events.recv().await {
            match event {
                PlayerEvent::Playing { .. } => println!("AUDIO_PLAYING"),
                PlayerEvent::EndOfTrack { .. } => { println!("AUDIO_COMPLETE"); return; },
                PlayerEvent::Unavailable { .. } => { println!("AUDIO_UNAVAILABLE"); return; },
                _ => {}
            }
        }
        println!("AUDIO_CHANNEL_CLOSED");
    }).await;
    if outcome.is_err() { println!("AUDIO_TIMEOUT"); }
    player.stop();
    session.shutdown();
}
