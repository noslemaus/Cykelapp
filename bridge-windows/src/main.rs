//! Cykelbrygga for Windows: the Bluetooth bridge between the trainer, heart rate straps, Zwift Click
//! and the game. It does what bridge/main.swift (the Mac bridge) does, with btleplug instead of
//! CoreBluetooth, and talks to the game the same way, so the game does not know which one it has.
//!
//! Telemetry goes to the game as JSON over UDP 127.0.0.1:47010; commands come back on 127.0.0.1:47011.
//! The bridge has no training logic: it only translates FTMS/Heart Rate packets to JSON and
//! JSON commands ("erg", "sim", "spindown", "release") to FTMS control-point writes.
//!
//! Safety: if control was taken and the game stops talking for 5 s, the trainer is reset
//! (FTMS opcode 0x01) so it never stays locked in ERG. After the game has spoken once and then
//! stays silent for 60 s, the bridge exits. "--read-only" ignores every trainer write.
//!
//! Trainers: every device advertising FTMS (smart trainers) or Cycling Power (also power meters) is
//! listed in the status ("trainers"). With "trainer": <id> in the game's commands the bridge only
//! connects to that one; without it, it takes the first smart trainer, and a device with only
//! Cycling Power when no smart trainer has shown up within 5 s.
//!
//! Zwift Click (v2 pair, or v1): the bridge connects, sends the "RideOn" greeting the controllers
//! wait for, decodes their key pad (message 0x23, protobuf field 1, a 0 bit = pressed) and sends
//! each change to the game as {"t":"button","id":"v_vanster","down":true}. Nothing else is ever
//! written to them. While the game says "controllersOnly" (pretend trainer in the game), the
//! bridge leaves trainers and straps alone and only talks to the Clicks.
//!
//! Windows: no console window; the game starts it next to Cykelapp.exe with --log <file>. A second
//! bridge finds the command port taken and exits, leaving the first one in charge.

#![cfg_attr(windows, windows_subsystem = "windows")]

use btleplug::api::bleuuid::uuid_from_u16;
use btleplug::api::{
    Central as _, CentralEvent, CentralState, CharPropFlags, Characteristic, Manager as _, Peripheral as _,
    ScanFilter, WriteType,
};
use btleplug::platform::{Adapter, Manager, Peripheral, PeripheralId};
use futures::StreamExt;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::fs::File;
use std::io::Write;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};
use tokio::net::UdpSocket;
use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};
use uuid::Uuid;

const TELEMETRY_PORT: u16 = 47010;
const COMMAND_PORT: u16 = 47011;

const FTMS_SERVICE: Uuid = uuid_from_u16(0x1826);
const CYCLING_POWER_SERVICE: Uuid = uuid_from_u16(0x1818);
const HEART_RATE_SERVICE: Uuid = uuid_from_u16(0x180D);
const INDOOR_BIKE_DATA: Uuid = uuid_from_u16(0x2AD2);
const CYCLING_POWER_MEASUREMENT: Uuid = uuid_from_u16(0x2A63);
const HEART_RATE_MEASUREMENT: Uuid = uuid_from_u16(0x2A37);
const FTMS_CONTROL_POINT: Uuid = uuid_from_u16(0x2AD9);
const FTMS_STATUS: Uuid = uuid_from_u16(0x2ADA); // Fitness Machine Status: spin down progress
const FTMS_FEATURE: Uuid = uuid_from_u16(0x2ACC); // Fitness Machine Feature: can it spin down?
const CLICK_SERVICE: Uuid = uuid_from_u16(0xFC82);
const CLICK_ASYNC: Uuid = Uuid::from_u128(0x00000002_19CA_4651_86E5_FA29DCDD09D1);
const CLICK_SYNC_RX: Uuid = Uuid::from_u128(0x00000003_19CA_4651_86E5_FA29DCDD09D1);
const CLICK_SYNC_TX: Uuid = Uuid::from_u128(0x00000004_19CA_4651_86E5_FA29DCDD09D1);
const ZWIFT_COMPANY_ID: u16 = 0x094A;
const RIDE_ON: [u8; 6] = [0x52, 0x69, 0x64, 0x65, 0x4F, 0x6E];

/// Key pad bits of the Click v2 pair (left: arrows and minus, right: A B Y Z and plus).
const CLICK_BUTTONS: [(u32, &str); 10] = [
    (0x00001, "v_vanster"), (0x00002, "v_upp"), (0x00004, "v_hoger"), (0x00008, "v_ner"), (0x00100, "v_vaxla"),
    (0x00010, "h_a"), (0x00020, "h_b"), (0x00040, "h_y"), (0x00080, "h_z"), (0x01000, "h_vaxla"),
];

// --- Log ---------------------------------------------------------------------------------------

static START: OnceLock<Instant> = OnceLock::new();
static LOG_FILE: OnceLock<Mutex<Option<File>>> = OnceLock::new();

fn log(message: &str) {
    let secs = START.get_or_init(Instant::now).elapsed().as_secs_f64();
    let line = format!("[{secs:6.1}s] {message}\n");
    if let Some(file) = LOG_FILE.get() {
        if let Ok(mut file) = file.lock() {
            if let Some(file) = file.as_mut() {
                let _ = file.write_all(line.as_bytes());
                let _ = file.flush();
            }
        }
    }
    let _ = std::io::stderr().write_all(line.as_bytes()); // goes nowhere without a console
}

struct Options {
    read_only: bool,
    log_path: Option<String>,
}

fn options() -> Options {
    let args: Vec<String> = std::env::args().collect();
    let mut o = Options { read_only: false, log_path: None };
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--read-only" => o.read_only = true,
            "--log" if i + 1 < args.len() => {
                o.log_path = Some(args[i + 1].clone());
                i += 1;
            }
            _ => {}
        }
        i += 1;
    }
    o
}

// --- Small helpers ------------------------------------------------------------------------------

/// A number from a game command, or `fallback`, kept between `low` and `high` (NaN gives `fallback`).
fn bounded(value: Option<&Value>, fallback: f64, low: f64, high: f64) -> f64 {
    match value.and_then(Value::as_f64) {
        Some(v) if v.is_finite() => v.clamp(low, high),
        _ => fallback,
    }
}

fn le16(value: i64) -> [u8; 2] {
    let v = value.clamp(i16::MIN as i64, i16::MAX as i64) as i16 as u16;
    [(v & 0xFF) as u8, (v >> 8) as u8]
}

fn u8_clamped(value: f64) -> u8 {
    value.round().clamp(0.0, 255.0) as u8
}

struct Reader<'a> {
    bytes: &'a [u8],
    offset: usize,
}

impl<'a> Reader<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Reader { bytes, offset: 0 }
    }
    fn u8(&mut self) -> Option<u8> {
        let v = *self.bytes.get(self.offset)?;
        self.offset += 1;
        Some(v)
    }
    fn u16(&mut self) -> Option<u16> {
        if self.offset + 2 > self.bytes.len() {
            return None;
        }
        let v = u16::from_le_bytes([self.bytes[self.offset], self.bytes[self.offset + 1]]);
        self.offset += 2;
        Some(v)
    }
    fn s16(&mut self) -> Option<i16> {
        self.u16().map(|v| v as i16)
    }
    fn skip(&mut self, n: usize) {
        self.offset = (self.offset + n).min(self.bytes.len());
    }
}

/// Field 1 varint of a protobuf message (the Click key pad map), or None.
fn protobuf_field1(bytes: &[u8]) -> Option<u64> {
    let mut i = 0usize;
    let varint = |i: &mut usize| -> Option<u64> {
        let mut value = 0u64;
        let mut shift = 0u32;
        while *i < bytes.len() {
            let b = bytes[*i];
            *i += 1;
            value |= u64::from(b & 0x7F) << shift;
            if b & 0x80 == 0 {
                return Some(value);
            }
            shift += 7;
            if shift > 63 {
                return None;
            }
        }
        None
    };
    while i < bytes.len() {
        let key = varint(&mut i)?;
        match key & 7 {
            0 => {
                let v = varint(&mut i)?;
                if key >> 3 == 1 {
                    return Some(v);
                }
            }
            1 => i += 8,
            2 => {
                let len = varint(&mut i)?;
                i = i.saturating_add(usize::try_from(len).ok()?);
            }
            5 => i += 4,
            _ => return None,
        }
    }
    None
}

// --- Events -------------------------------------------------------------------------------------

#[derive(Clone, Copy, PartialEq, Debug)]
enum Kind {
    Trainer,
    Strap,
    Click,
}

enum Ev {
    Command(Value),
    Central(CentralEvent),
    /// A device is connected and set up (services found, notifications on, greeting sent).
    Ready { id: PeripheralId, kind: Kind, smart: bool, writer: Option<UnboundedSender<Vec<u8>>> },
    ConnectFailed { id: PeripheralId, kind: Kind, reason: String },
    Notify { id: PeripheralId, uuid: Uuid, value: Vec<u8> },
    Tick,
}

struct Click {
    is_v2: bool,
    pressed: u32,
    greeted: bool,
    reported_buttons: bool,
    locked_challenge: bool,
    connected_at: Instant,
}

struct SeenTrainer {
    name: String,
    smart: bool,
    rssi: i16,
}

// --- Connecting (each in its own task; the result comes back as an event) ------------------------

async fn connect_device(peripheral: Peripheral, kind: Kind, is_v2: bool, tx: UnboundedSender<Ev>) {
    let id = peripheral.id();
    let result = setup(&peripheral, kind, is_v2, &tx).await;
    match result {
        Ok((smart, writer)) => {
            let _ = tx.send(Ev::Ready { id, kind, smart, writer });
        }
        Err(reason) => {
            let _ = peripheral.disconnect().await;
            let _ = tx.send(Ev::ConnectFailed { id, kind, reason });
        }
    }
}

type Setup = Result<(bool, Option<UnboundedSender<Vec<u8>>>), String>;

async fn setup(p: &Peripheral, kind: Kind, is_v2: bool, tx: &UnboundedSender<Ev>) -> Setup {
    if !p.is_connected().await.unwrap_or(false) {
        p.connect_with_timeout(Duration::from_secs(20)).await.map_err(|e| e.to_string())?;
    }
    p.discover_services_with_timeout(Duration::from_secs(20)).await.map_err(|e| e.to_string())?;
    // Listen before subscribing, so the first values are not lost.
    let mut notes = p.notifications().await.map_err(|e| e.to_string())?;
    let (id, forward) = (p.id(), tx.clone());
    tokio::spawn(async move {
        while let Some(n) = notes.next().await {
            if forward.send(Ev::Notify { id: id.clone(), uuid: n.uuid, value: n.value }).is_err() {
                break;
            }
        }
    });
    let chars = p.characteristics();
    let find = |uuid: Uuid| chars.iter().find(|c| c.uuid == uuid).cloned();
    let can_listen = |c: &Characteristic| c.properties.intersects(CharPropFlags::NOTIFY | CharPropFlags::INDICATE);
    match kind {
        Kind::Click => {
            for uuid in [CLICK_ASYNC, CLICK_SYNC_TX] {
                if let Some(c) = find(uuid) {
                    p.subscribe(&c).await.map_err(|e| e.to_string())?;
                }
            }
            let rx = find(CLICK_SYNC_RX).ok_or("ingen Click-kanal")?;
            // The greeting the controllers wait for before they report buttons.
            let mut greeting = RIDE_ON.to_vec();
            if is_v2 {
                greeting.extend_from_slice(&[0x02, 0x03]);
            }
            let kind = if rx.properties.contains(CharPropFlags::WRITE_WITHOUT_RESPONSE) {
                WriteType::WithoutResponse
            } else {
                WriteType::WithResponse
            };
            p.write(&rx, &greeting, kind).await.map_err(|e| e.to_string())?;
            Ok((false, None))
        }
        Kind::Strap => {
            let hr = find(HEART_RATE_MEASUREMENT).ok_or("ingen pulskanal")?;
            p.subscribe(&hr).await.map_err(|e| e.to_string())?;
            Ok((false, None))
        }
        Kind::Trainer => {
            for uuid in [INDOOR_BIKE_DATA, CYCLING_POWER_MEASUREMENT, HEART_RATE_MEASUREMENT, FTMS_STATUS] {
                if let Some(c) = find(uuid).filter(can_listen) {
                    p.subscribe(&c).await.map_err(|e| e.to_string())?;
                }
            }
            let smart = p.services().iter().any(|s| s.uuid == FTMS_SERVICE);
            let mut writer = None;
            if let Some(cp) = find(FTMS_CONTROL_POINT) {
                p.subscribe(&cp).await.map_err(|e| e.to_string())?; // indications carry the responses
                // One writer task per trainer, so control-point writes reach it in order.
                let (wtx, mut wrx) = unbounded_channel::<Vec<u8>>();
                let p2 = p.clone();
                tokio::spawn(async move {
                    while let Some(bytes) = wrx.recv().await {
                        if let Err(e) = p2.write(&cp, &bytes, WriteType::WithResponse).await {
                            log(&format!("FEL vid skrivning till trainern: {e}"));
                        }
                    }
                });
                writer = Some(wtx);
            }
            if let Some(feature) = find(FTMS_FEATURE) {
                if let Ok(value) = p.read(&feature).await {
                    let _ = tx.send(Ev::Notify { id: p.id(), uuid: FTMS_FEATURE, value });
                }
            }
            Ok((smart, writer))
        }
    }
}

// --- The bridge ---------------------------------------------------------------------------------

struct Bridge {
    tx: UnboundedSender<Ev>,
    socket: Arc<UdpSocket>,
    read_only: bool,
    adapter: Option<Adapter>,
    adapter_checked: Instant,

    trainer: Option<PeripheralId>,
    trainer_name: String,
    trainer_state: String, // söker | ansluter | klar | bara watt | Bluetooth avstängt | ingen Bluetooth
    writer: Option<UnboundedSender<Vec<u8>>>,
    straps: HashMap<PeripheralId, String>,
    clicks: HashMap<PeripheralId, Click>,
    buttons_down: u32, // union of what every Click reports as pressed
    controllers_only: bool, // the game rides the pretend trainer: Clicks only

    // Trainers seen while scanning, and the one the player picked (None = the first smart trainer).
    seen: HashMap<PeripheralId, SeenTrainer>,
    wanted: Option<String>,
    scan_started: Instant,

    // Latest values.
    power: Option<i64>,
    cadence: Option<f64>,
    speed_kmh: Option<f64>,
    strap_hr: Option<(i64, Instant, String)>,
    relay_hr: Option<i64>,

    // Spin down (calibration): None = not known yet, then what the trainer's FTMS features say.
    spindown_supported: Option<bool>,
    spindown_active: bool,

    // Control state.
    control: &'static str, // ingen | begärd | given | nekad
    pending: Option<Vec<u8>>,
    last_game_message: Option<Instant>,
}

impl Bridge {
    fn send(&self, object: Value) {
        if let Ok(bytes) = serde_json::to_vec(&object) {
            let _ = self.socket.try_send_to(&bytes, ([127, 0, 0, 1], TELEMETRY_PORT).into());
        }
    }

    // Bluetooth adapter: found at start, or later (a USB dongle plugged in).
    async fn find_adapter(&mut self) {
        self.adapter_checked = Instant::now();
        let adapter = match Manager::new().await {
            Ok(manager) => manager.adapters().await.ok().and_then(|list| list.into_iter().next()),
            Err(_) => None,
        };
        let Some(adapter) = adapter else {
            if self.trainer_state != "ingen Bluetooth" {
                log("FEL: datorn har ingen Bluetooth (en USB-dongel för Bluetooth 4.0 eller senare fungerar).");
            }
            self.trainer_state = "ingen Bluetooth".into();
            return;
        };
        match adapter.events().await {
            Ok(mut events) => {
                let tx = self.tx.clone();
                tokio::spawn(async move {
                    while let Some(e) = events.next().await {
                        if tx.send(Ev::Central(e)).is_err() {
                            break;
                        }
                    }
                });
            }
            Err(e) => log(&format!("FEL: kan inte lyssna på Bluetooth: {e}")),
        }
        self.adapter = Some(adapter);
        self.trainer_state = "söker".into();
        self.scan().await;
    }

    async fn scan(&mut self) {
        let Some(adapter) = &self.adapter else { return };
        match adapter.adapter_state().await {
            Ok(CentralState::PoweredOff) => {
                if self.trainer.is_none() {
                    self.trainer_state = "Bluetooth avstängt".into();
                }
                log("FEL: Bluetooth är avstängt.");
                return;
            }
            _ => {}
        }
        // Every device is looked at: a filter would miss Clicks that only show Zwift's company id.
        match adapter.start_scan(ScanFilter::default()).await {
            Ok(()) => {
                self.scan_started = Instant::now();
                log("Bluetooth på, söker trainer, pulsband och Zwift Click.");
            }
            Err(e) => log(&format!("FEL: kan inte söka med Bluetooth: {e}")),
        }
    }

    async fn peripheral(&self, id: &PeripheralId) -> Option<Peripheral> {
        self.adapter.as_ref()?.peripheral(id).await.ok()
    }

    async fn disconnect(&self, id: &PeripheralId) {
        if let Some(p) = self.peripheral(id).await {
            tokio::spawn(async move {
                let _ = p.disconnect().await;
            });
        }
    }

    async fn connect(&self, id: &PeripheralId, kind: Kind, is_v2: bool) {
        if let Some(p) = self.peripheral(id).await {
            tokio::spawn(connect_device(p, kind, is_v2, self.tx.clone()));
        }
    }

    // MARK: Game commands

    async fn handle_command(&mut self, command: Value) {
        if self.last_game_message.is_none() {
            log("Spelet har anslutit");
        }
        self.last_game_message = Some(Instant::now());
        let name = command.get("cmd").and_then(Value::as_str).unwrap_or("").to_string();
        if !name.is_empty() && name != "ping" {
            log(&format!("Kommando från spelet: {name}"));
        }
        if let Some(only) = command.get("controllersOnly").and_then(Value::as_bool) {
            if only != self.controllers_only {
                self.set_controllers_only(only).await;
            }
        }
        if let Some(id) = command.get("trainer").and_then(Value::as_str) {
            let wanted = if id.is_empty() { None } else { Some(id.to_string()) };
            self.set_wanted_trainer(wanted).await;
        }
        match name.as_str() {
            "erg" => {
                let watts = command.get("watts").and_then(Value::as_f64).filter(|w| w.is_finite()).unwrap_or(0.0);
                let watts = (watts as i64).clamp(0, 2000);
                let mut bytes = vec![0x05];
                bytes.extend_from_slice(&le16(watts));
                self.submit(bytes, &format!("ERG {watts} W"));
            }
            "sim" => {
                // Every value is kept within what FTMS can carry before it becomes an integer.
                let grade = bounded(command.get("grade"), 0.0, -40.0, 40.0); // percent
                let crr = bounded(command.get("crr"), 0.004, 0.0, 0.025);
                let cw = bounded(command.get("cw"), 0.51, 0.0, 2.55); // kg/m
                let wind = bounded(command.get("wind"), 0.0, -30.0, 30.0); // m/s
                let mut bytes = vec![0x11];
                bytes.extend_from_slice(&le16((wind * 1000.0).round() as i64));
                bytes.extend_from_slice(&le16((grade * 100.0).round() as i64));
                bytes.push(u8_clamped(crr * 10000.0));
                bytes.push(u8_clamped(cw * 100.0));
                self.submit(bytes, &format!("SIM {grade:.1} %"));
            }
            "spindown" => {
                // FTMS Spin Down Control (0x13, start): the trainer answers with the speed to pedal up
                // to, then reports through Fitness Machine Status when to stop and how it went.
                if self.trainer.is_none() || self.writer.is_none() {
                    self.send(json!({"t": "spindown", "state": "fel", "reason": "ingen trainer"}));
                    return;
                }
                self.spindown_active = true;
                self.send(json!({"t": "spindown", "state": "begärd"}));
                self.submit(vec![0x13, 0x01], "kalibrering");
            }
            "release" => self.release("spelet bad om det"),
            "quit" => {
                self.release("spelet avslutas");
                self.quit().await;
            }
            _ => {} // "ping" and unknown commands only refresh the watchdog
        }
    }

    /// Pretend trainer in the game: let go of the trainer and straps and only keep the Clicks.
    /// Real trainer again: look for it as usual.
    async fn set_controllers_only(&mut self, only: bool) {
        self.controllers_only = only;
        log(if only { "Bara handkontroller (spelet kör låtsastrainern)." } else { "Söker trainer och pulsband igen." });
        if only {
            self.release("spelet kör låtsastrainern");
            if let Some(trainer) = self.trainer.clone() {
                self.disconnect(&trainer).await;
                self.forget(&trainer);
            }
            for strap in self.straps.keys().cloned().collect::<Vec<_>>() {
                self.disconnect(&strap).await;
            }
            self.straps.clear();
        }
    }

    /// The player picked a trainer (or "the first one found" again): let go of another one.
    async fn set_wanted_trainer(&mut self, id: Option<String>) {
        if id == self.wanted {
            return;
        }
        self.wanted = id.clone();
        let what = match &id {
            None => "första som hittas".to_string(),
            Some(id) => self
                .seen
                .iter()
                .find(|(k, _)| &k.to_string() == id)
                .map(|(_, t)| t.name.clone())
                .unwrap_or_else(|| "inte sedd än".into()),
        };
        log(&format!("Vald trainer: {what}"));
        if let (Some(trainer), Some(id)) = (self.trainer.clone(), id) {
            if trainer.to_string() != id {
                self.release("byter trainer");
                self.disconnect(&trainer).await;
                self.forget(&trainer);
            }
        }
        self.pick_trainer().await;
    }

    /// Connect to the picked trainer once it has been seen, or else to the best one on offer.
    async fn pick_trainer(&mut self) {
        if self.trainer.is_some() || self.controllers_only || self.adapter.is_none() {
            return;
        }
        let choice = match &self.wanted {
            Some(wanted) => self.seen.iter().find(|(id, _)| &id.to_string() == wanted).map(|(id, _)| id.clone()),
            None => {
                // A power meter on the bike also has Cycling Power: wait a moment for a smart trainer.
                let best = |smart_only: bool| {
                    self.seen
                        .iter()
                        .filter(|(_, t)| t.smart || !smart_only)
                        .max_by_key(|(_, t)| t.rssi)
                        .map(|(id, _)| id.clone())
                };
                best(true).or_else(|| if self.scan_started.elapsed() > Duration::from_secs(5) { best(false) } else { None })
            }
        };
        let Some(id) = choice else { return };
        let name = self.seen.get(&id).map(|t| t.name.clone()).unwrap_or_else(|| "Trainer".into());
        self.trainer = Some(id.clone());
        self.trainer_name = name.clone();
        self.trainer_state = "ansluter".into();
        log(&format!("Ansluter till trainer {name}"));
        self.connect(&id, Kind::Trainer, false).await;
    }

    /// Queue a control-point write; take control first if needed. Only the latest command is kept.
    fn submit(&mut self, bytes: Vec<u8>, label: &str) {
        if self.read_only || self.controllers_only {
            return;
        }
        self.pending = Some(bytes);
        let Some(writer) = self.writer.clone() else { return };
        match self.control {
            "given" => self.flush_pending(),
            "begärd" => {}
            _ => {
                log(&format!("Begär kontroll över trainern ({label})"));
                self.control = "begärd";
                let _ = writer.send(vec![0x00]);
            }
        }
    }

    fn flush_pending(&mut self) {
        if let (Some(bytes), Some(writer)) = (self.pending.take(), &self.writer) {
            let _ = writer.send(bytes);
        }
    }

    /// FTMS reset (0x01) puts the trainer back to its default free-running state.
    fn release(&mut self, reason: &str) {
        self.pending = None;
        if matches!(self.control, "given" | "begärd") {
            if let Some(writer) = &self.writer {
                log(&format!("Släpper trainern: {reason}"));
                let _ = writer.send(vec![0x01]);
            }
        }
        self.control = "ingen";
    }

    async fn tick(&mut self) {
        if self.adapter.is_none() && self.adapter_checked.elapsed() > Duration::from_secs(5) {
            self.find_adapter().await;
        }
        self.pick_trainer().await;
        if let Some(last) = self.last_game_message {
            let silence = last.elapsed();
            if silence > Duration::from_secs(5) && self.control != "ingen" {
                self.release("spelet har varit tyst i 5 s");
            }
            if silence > Duration::from_secs(60) {
                log("Spelet har varit tyst i 60 s, avslutar.");
                self.quit().await;
            }
        }
        let ready: Vec<&Click> = self.clicks.values().filter(|c| c.greeted).collect();
        let locked = ready.iter().any(|c| {
            !c.reported_buttons && (c.locked_challenge || c.connected_at.elapsed() > Duration::from_secs(20))
        });
        let mut trainers: Vec<(&PeripheralId, &SeenTrainer)> = self.seen.iter().collect();
        trainers.sort_by(|a, b| a.1.name.cmp(&b.1.name));
        let hr = match &self.strap_hr {
            Some((_, _, name)) => json!(name),
            None if self.relay_hr.is_some() => json!("via trainern"),
            None => Value::Null,
        };
        self.send(json!({
            "t": "status",
            "trainer": self.trainer.as_ref().map(|_| self.trainer_name.clone()),
            "trainerId": self.trainer.as_ref().map(|id| id.to_string()),
            "trainers": trainers.iter().map(|(id, t)| json!({"id": id.to_string(), "name": t.name, "smart": t.smart})).collect::<Vec<_>>(),
            "trainerState": self.trainer_state,
            "hr": hr,
            "control": self.control,
            "readOnly": self.read_only,
            "clicks": ready.len(),
            "clicksLocked": locked && !ready.iter().any(|c| c.reported_buttons),
            "controllersOnly": self.controllers_only,
            "spindown": self.spindown_supported,
        }));
    }

    async fn quit(&mut self) {
        if let Some(adapter) = &self.adapter {
            let _ = adapter.stop_scan().await;
        }
        let mut all: Vec<PeripheralId> = self.straps.keys().cloned().collect();
        all.extend(self.clicks.keys().cloned());
        all.extend(self.trainer.clone());
        for id in all {
            if let Some(p) = self.peripheral(&id).await {
                let _ = tokio::time::timeout(Duration::from_millis(500), p.disconnect()).await;
            }
        }
        tokio::time::sleep(Duration::from_millis(300)).await; // the release write goes out first
        std::process::exit(0);
    }

    // MARK: Bluetooth

    async fn central_event(&mut self, event: CentralEvent) {
        match event {
            CentralEvent::DeviceDiscovered(id)
            | CentralEvent::DeviceUpdated(id)
            | CentralEvent::ServicesAdvertisement { id, .. }
            | CentralEvent::ManufacturerDataAdvertisement { id, .. } => self.discovered(id).await,
            CentralEvent::DeviceDisconnected(id) => self.disconnected(id).await,
            CentralEvent::StateUpdate(CentralState::PoweredOff) => {
                if self.trainer.is_none() {
                    self.trainer_state = "Bluetooth avstängt".into();
                }
                log("FEL: Bluetooth är avstängt.");
            }
            CentralEvent::StateUpdate(CentralState::PoweredOn) => {
                if self.trainer.is_none() {
                    self.trainer_state = "söker".into();
                }
                self.scan().await;
            }
            _ => {}
        }
    }

    async fn discovered(&mut self, id: PeripheralId) {
        if self.clicks.contains_key(&id) || self.straps.contains_key(&id) || self.trainer.as_ref() == Some(&id) {
            return; // already ours
        }
        let Some(p) = self.peripheral(&id).await else { return };
        let Ok(Some(props)) = p.properties().await else { return };
        let services = &props.services;
        let maker = props.manufacturer_data.get(&ZWIFT_COMPANY_ID);
        let is_trainer = services.contains(&FTMS_SERVICE) || services.contains(&CYCLING_POWER_SERVICE);
        // A Zwift Hub trainer also carries Zwift's company id: a trainer service makes it a trainer.
        if (services.contains(&CLICK_SERVICE) || maker.is_some()) && !is_trainer {
            if self.clicks.len() >= 4 {
                return;
            }
            let kind = maker.and_then(|m| m.first().copied());
            let is_v2 = matches!(kind, Some(0x0A) | Some(0x0B)) || services.contains(&CLICK_SERVICE);
            let side = match kind {
                Some(0x0B) => " vänster",
                Some(0x0A) => " höger",
                _ => "",
            };
            log(&format!("Ansluter till Zwift Click{side}"));
            self.clicks.insert(
                id.clone(),
                Click { is_v2, pressed: 0, greeted: false, reported_buttons: false, locked_challenge: false, connected_at: Instant::now() },
            );
            self.connect(&id, Kind::Click, is_v2).await;
            return;
        }
        if self.controllers_only {
            return;
        }
        let name = props.local_name.clone().or(props.advertisement_name.clone());
        if is_trainer {
            let name = name.unwrap_or_else(|| "Trainer".into());
            let smart = services.contains(&FTMS_SERVICE);
            if !self.seen.contains_key(&id) {
                log(&format!("Hittade {name}{}", if smart { " (smart trainer)" } else { " (wattmätare)" }));
            }
            self.seen.insert(id, SeenTrainer { name, smart, rssi: props.rssi.unwrap_or(-127) });
            self.pick_trainer().await;
        } else if services.contains(&HEART_RATE_SERVICE) && self.straps.len() < 2 {
            let name = name.unwrap_or_else(|| "pulsband".into());
            log(&format!("Ansluter till pulsband {name}"));
            self.straps.insert(id.clone(), name);
            self.connect(&id, Kind::Strap, false).await;
        }
    }

    async fn disconnected(&mut self, id: PeripheralId) {
        if let Some(click) = self.clicks.get_mut(&id) {
            // Let go of anything it held down, then reconnect when it wakes up again.
            log("Frånkopplad: Zwift Click");
            click.pressed = 0;
            click.greeted = false;
            let is_v2 = click.is_v2;
            self.update_buttons();
            self.connect(&id, Kind::Click, is_v2).await;
            return;
        }
        if self.trainer.as_ref() == Some(&id) || self.straps.contains_key(&id) {
            log(&format!("Frånkopplad: {}", if self.trainer.as_ref() == Some(&id) { &self.trainer_name } else { "pulsband" }));
            self.forget(&id);
        }
    }

    /// A connection that never came about or went away: forget the device and look again.
    fn forget(&mut self, id: &PeripheralId) {
        if self.trainer.as_ref() == Some(id) {
            self.trainer = None;
            self.writer = None;
            self.control = "ingen";
            self.trainer_state = "söker".into();
            self.power = None;
            self.cadence = None;
            self.speed_kmh = None;
            self.relay_hr = None;
            self.spindown_supported = None;
            if self.spindown_active {
                self.spindown_active = false;
                self.send(json!({"t": "spindown", "state": "fel", "reason": "trainern kopplades från"}));
            }
        } else {
            self.straps.remove(id);
        }
    }

    async fn ready(&mut self, id: PeripheralId, kind: Kind, smart: bool, writer: Option<UnboundedSender<Vec<u8>>>) {
        match kind {
            Kind::Click => {
                if let Some(click) = self.clicks.get_mut(&id) {
                    click.greeted = true;
                    click.connected_at = Instant::now();
                    log("Zwift Click redo");
                }
            }
            Kind::Strap => log(&format!("Pulsband anslutet: {}", self.straps.get(&id).map(String::as_str).unwrap_or("?"))),
            Kind::Trainer => {
                if self.trainer.as_ref() != Some(&id) {
                    self.disconnect(&id).await; // switched to another one meanwhile
                    return;
                }
                self.writer = writer;
                self.trainer_state = if smart { "klar" } else { "bara watt" }.into();
                log(&format!("Trainer klar: {}", self.trainer_name));
            }
        }
    }

    fn connect_failed(&mut self, id: PeripheralId, kind: Kind, reason: String) {
        log(&format!("Kunde inte ansluta ({kind:?}): {reason}"));
        if kind == Kind::Click {
            self.clicks.remove(&id);
            self.update_buttons();
        } else {
            self.forget(&id);
        }
    }

    fn notify(&mut self, id: PeripheralId, uuid: Uuid, value: Vec<u8>) {
        if self.clicks.contains_key(&id) {
            self.parse_click(&id, &value);
            return;
        }
        match uuid {
            INDOOR_BIKE_DATA => self.parse_indoor_bike_data(&value),
            CYCLING_POWER_MEASUREMENT if self.writer.is_none() => self.parse_cycling_power(&value),
            HEART_RATE_MEASUREMENT => self.parse_heart_rate(&id, &value),
            FTMS_CONTROL_POINT => self.parse_control_response(&value),
            FTMS_STATUS => self.parse_machine_status(&value),
            FTMS_FEATURE => self.parse_features(&value),
            _ => {}
        }
    }

    /// FTMS Indoor Bike Data (0x2AD2). Bit 0 = "More Data": when 0, instantaneous speed is present.
    fn parse_indoor_bike_data(&mut self, data: &[u8]) {
        let mut r = Reader::new(data);
        let Some(flags) = r.u16() else { return };
        if flags & 0x0001 == 0 {
            if let Some(v) = r.u16() {
                self.speed_kmh = Some(f64::from(v) / 100.0);
            }
        }
        if flags & 0x0002 != 0 {
            r.skip(2);
        }
        if flags & 0x0004 != 0 {
            if let Some(v) = r.u16() {
                self.cadence = Some(f64::from(v) / 2.0);
            }
        }
        if flags & 0x0008 != 0 {
            r.skip(2);
        }
        if flags & 0x0010 != 0 {
            r.skip(3);
        }
        if flags & 0x0020 != 0 {
            r.skip(2);
        }
        if flags & 0x0040 != 0 {
            if let Some(v) = r.s16() {
                self.power = Some(i64::from(v));
            }
        }
        self.send_data();
    }

    fn parse_cycling_power(&mut self, data: &[u8]) {
        let mut r = Reader::new(data);
        if r.u16().is_none() {
            return;
        }
        let Some(p) = r.s16() else { return };
        self.power = Some(i64::from(p));
        self.send_data();
    }

    fn parse_heart_rate(&mut self, id: &PeripheralId, data: &[u8]) {
        let mut r = Reader::new(data);
        let Some(flags) = r.u8() else { return };
        let bpm = if flags & 0x01 == 0 { r.u8().map(i64::from) } else { r.u16().map(i64::from) };
        let Some(bpm) = bpm else { return };
        if self.trainer.as_ref() == Some(id) {
            self.relay_hr = Some(bpm);
        } else {
            let name = self.straps.get(id).cloned().unwrap_or_else(|| "pulsband".into());
            self.strap_hr = Some((bpm, Instant::now(), name));
        }
    }

    /// A Click message: 0x23 = key pad (field 1, a 0 bit = pressed). FF 03 … is the unlock challenge
    /// a Click v2 sends when it has not been connected to the Zwift app lately.
    fn parse_click(&mut self, id: &PeripheralId, bytes: &[u8]) {
        let Some(click) = self.clicks.get_mut(id) else { return };
        let Some(&kind) = bytes.first() else { return };
        if kind == 0xFF && bytes.len() > 1 && bytes[1] == 0x03 {
            if !click.locked_challenge {
                log("Zwift Click ber om upplåsning (anslut den i Zwift-appen en gång per dygn)");
            }
            click.locked_challenge = true;
            return;
        }
        if kind != 0x23 {
            return;
        }
        let Some(map) = protobuf_field1(&bytes[1..]) else { return };
        if !click.reported_buttons {
            log("Zwift Click skickar knapptryck");
        }
        click.reported_buttons = true;
        click.pressed = !(map as u32) & 0x1FFFF;
        self.update_buttons();
    }

    /// Send every button that went down or up since last time (the Clicks report each other's
    /// presses too, so their reports are combined).
    fn update_buttons(&mut self) {
        let now = self.clicks.values().fold(0u32, |acc, c| acc | c.pressed);
        let changed = now ^ self.buttons_down;
        if changed == 0 {
            return;
        }
        for (bit, name) in CLICK_BUTTONS {
            if changed & bit != 0 {
                self.send(json!({"t": "button", "id": name, "down": now & bit != 0}));
            }
        }
        self.buttons_down = now;
    }

    /// Control-point indication: 0x80, request opcode, result (0x01 = success).
    fn parse_control_response(&mut self, bytes: &[u8]) {
        if bytes.len() < 3 || bytes[0] != 0x80 {
            return;
        }
        let (opcode, result) = (bytes[1], bytes[2]);
        if opcode == 0x00 {
            if result == 0x01 {
                self.control = "given";
                log("Kontroll beviljad");
                if let Some(writer) = &self.writer {
                    let _ = writer.send(vec![0x07]); // start/resume
                }
                self.flush_pending();
            } else {
                self.control = "nekad";
                log(&format!("Kontroll nekad (kod {result}). Är Zwift eller en cykeldator kopplad som styrd trainer?"));
            }
        } else if opcode == 0x13 {
            if result == 0x01 && bytes.len() >= 7 {
                let low = f64::from(u16::from_le_bytes([bytes[3], bytes[4]])) / 100.0;
                let high = f64::from(u16::from_le_bytes([bytes[5], bytes[6]])) / 100.0;
                log(&format!("Kalibrering: trampa upp till {low:.0}–{high:.0} km/h"));
                self.send(json!({"t": "spindown", "state": "trampa", "low": low, "high": high}));
            } else if result == 0x01 {
                self.send(json!({"t": "spindown", "state": "trampa"}));
            } else {
                self.spindown_active = false;
                log(&format!("Kalibreringen nekades (kod {result})"));
                let reason = if result == 0x02 { "stöds inte".to_string() } else { format!("kod {result}") };
                self.send(json!({"t": "spindown", "state": "fel", "reason": reason}));
                self.release("kalibreringen nekades");
            }
        } else if result != 0x01 {
            log(&format!("Trainern svarade med fel {result} på kommando 0x{opcode:02X}"));
        }
    }

    /// Fitness Machine Status (0x2ADA): 0x14 = spin down status (1 requested, 2 success, 3 error,
    /// 4 stop pedalling). Other status messages are ignored.
    fn parse_machine_status(&mut self, bytes: &[u8]) {
        if bytes.len() < 2 || bytes[0] != 0x14 {
            return;
        }
        match bytes[1] {
            0x01 => self.send(json!({"t": "spindown", "state": "trampa"})),
            0x04 => self.send(json!({"t": "spindown", "state": "sluta"})),
            0x02 | 0x03 => {
                let ok = bytes[1] == 0x02;
                log(if ok { "Kalibreringen lyckades" } else { "Kalibreringen misslyckades" });
                self.spindown_active = false;
                self.send(json!({"t": "spindown", "state": if ok { "klar" } else { "fel" },
                                 "reason": if ok { "" } else { "trainern rapporterade fel" }}));
                self.release("kalibreringen är klar");
            }
            _ => {}
        }
    }

    /// Fitness Machine Feature (0x2ACC): two 32-bit fields; bit 15 of the second (target settings)
    /// says the trainer can spin down on command.
    fn parse_features(&mut self, bytes: &[u8]) {
        if bytes.len() < 8 {
            return;
        }
        let targets = u32::from_le_bytes([bytes[4], bytes[5], bytes[6], bytes[7]]);
        let can = targets & (1 << 15) != 0;
        self.spindown_supported = Some(can);
        log(&format!("Trainern kan {}kalibreras via FTMS", if can { "" } else { "inte " }));
    }

    fn send_data(&self) {
        let hr = match &self.strap_hr {
            Some((bpm, at, _)) if at.elapsed() < Duration::from_secs(3) => Some(*bpm),
            _ => self.relay_hr,
        };
        self.send(json!({"t": "data", "power": self.power, "cadence": self.cadence, "speed": self.speed_kmh, "hr": hr}));
    }
}

#[tokio::main]
async fn main() {
    START.get_or_init(Instant::now);
    let opts = options();
    let file = opts.log_path.as_ref().and_then(|path| File::create(path).ok());
    let _ = LOG_FILE.set(Mutex::new(file));
    log(&format!(
        "Cykelbrygga {} startar{}.",
        env!("CARGO_PKG_VERSION"),
        if opts.read_only { " (skrivskyddad: skriver aldrig till trainern)" } else { "" }
    ));

    // One plain socket bound to the command port: commands are read from any sender, telemetry is
    // sent to the game's port. A taken port means another bridge already serves the game.
    let socket = match UdpSocket::bind(("127.0.0.1", COMMAND_PORT)).await {
        Ok(s) => Arc::new(s),
        Err(_) => {
            log(&format!("Kommandoporten {COMMAND_PORT} är upptagen: en annan Cykelbrygga kör redan. Avslutar."));
            return;
        }
    };
    let (tx, mut rx) = unbounded_channel::<Ev>();
    {
        let (socket, tx) = (socket.clone(), tx.clone());
        tokio::spawn(async move {
            let mut buffer = [0u8; 4096];
            loop {
                if let Ok((n, _)) = socket.recv_from(&mut buffer).await {
                    if let Ok(v @ Value::Object(_)) = serde_json::from_slice::<Value>(&buffer[..n]) {
                        if tx.send(Ev::Command(v)).is_err() {
                            break;
                        }
                    }
                }
            }
        });
    }
    {
        let tx = tx.clone();
        tokio::spawn(async move {
            let mut every = tokio::time::interval(Duration::from_secs(1));
            loop {
                every.tick().await;
                if tx.send(Ev::Tick).is_err() {
                    break;
                }
            }
        });
    }

    let mut bridge = Bridge {
        tx,
        socket,
        read_only: opts.read_only,
        adapter: None,
        adapter_checked: Instant::now(),
        trainer: None,
        trainer_name: String::new(),
        trainer_state: "söker".into(),
        writer: None,
        straps: HashMap::new(),
        clicks: HashMap::new(),
        buttons_down: 0,
        controllers_only: false,
        seen: HashMap::new(),
        wanted: None,
        scan_started: Instant::now(),
        power: None,
        cadence: None,
        speed_kmh: None,
        strap_hr: None,
        relay_hr: None,
        spindown_supported: None,
        spindown_active: false,
        control: "ingen",
        pending: None,
        last_game_message: None,
    };
    bridge.find_adapter().await;

    while let Some(event) = rx.recv().await {
        match event {
            Ev::Command(command) => bridge.handle_command(command).await,
            Ev::Central(e) => bridge.central_event(e).await,
            Ev::Ready { id, kind, smart, writer } => bridge.ready(id, kind, smart, writer).await,
            Ev::ConnectFailed { id, kind, reason } => bridge.connect_failed(id, kind, reason),
            Ev::Notify { id, uuid, value } => bridge.notify(id, uuid, value),
            Ev::Tick => bridge.tick().await,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn click_keypad_from_protobuf() {
        // Field 1 varint 0x1FFFE: every bit 1 (released) except bit 0 (left arrow pressed).
        let msg = [0x08, 0xFE, 0xFF, 0x07];
        let map = protobuf_field1(&msg).unwrap();
        assert_eq!(!(map as u32) & 0x1FFFF, 0x00001);
        // Another field first (length-delimited), then field 1.
        assert_eq!(protobuf_field1(&[0x12, 0x02, 0xAA, 0xBB, 0x08, 0x05]), Some(5));
        assert_eq!(protobuf_field1(&[0xFF]), None);
    }

    #[test]
    fn sim_and_erg_bytes() {
        assert_eq!(le16(150), [150, 0]);
        assert_eq!(le16(-250), [0x06, 0xFF]);
        assert_eq!(le16(100_000), [0xFF, 0x7F]); // clamped, never wraps
        assert_eq!(u8_clamped(0.004 * 10000.0), 40);
        assert_eq!(u8_clamped(9999.0), 255);
        assert_eq!(bounded(Some(&json!(f64::NAN)), 1.0, 0.0, 2.0), 1.0);
        assert_eq!(bounded(Some(&json!(50)), 0.0, -40.0, 40.0), 40.0);
        assert_eq!(bounded(None, 0.51, 0.0, 2.55), 0.51);
    }

    #[test]
    fn indoor_bike_data_reader() {
        // Flags 0x0044: speed present (bit 0 clear), cadence (bit 2) and power (bit 6).
        let data = [0x44, 0x00, 0xE8, 0x03, 0xB4, 0x00, 0xC8, 0x00];
        let mut r = Reader::new(&data);
        let flags = r.u16().unwrap();
        assert_eq!(flags, 0x44);
        assert_eq!(r.u16(), Some(1000)); // 10.00 km/h
        assert_eq!(r.u16(), Some(180)); // 90 rpm
        assert_eq!(r.s16(), Some(200)); // 200 W
        assert_eq!(r.u8(), None);
    }
}
