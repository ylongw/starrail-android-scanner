# starrail-android-scanner

Export your **Honkai: Star Rail** relic inventory, characters, and light cones from an Android device — **no root, no Windows required**.

> Works on **macOS (Apple Silicon & Intel)** + any **Android device** running the game.

---

## How it works

```
Android (K80 / any phone)          macOS (Mac mini / MacBook)
─────────────────────────          ──────────────────────────
PCAPdroid (VPNService)       →     convert_pcap.py
  captures game UDP traffic          fixes pcap LinkType
  on game startup (no root)    →     reliquary-archiver --pcap
  exports raw .pcap file               decrypts & parses protobuf
                               →     hsr_output.json  ✅
```

The game uses a **custom UDP protocol** (not HTTPS).  
On startup it performs a **key negotiation handshake** — `reliquary-archiver` extracts the session key and uses it to decrypt every subsequent packet, then parses the protobuf payloads to reconstruct your full inventory.

**The missing piece** that makes this work on Android: PCAPdroid captures via the Android VPN layer (`TUN` interface), producing pcap files with **LinkType 101** (Raw IP, no Ethernet header). `reliquary-archiver` expects **LinkType 1** (Ethernet). The `convert_pcap.py` script in this repo patches this in ~0.1 seconds.

---

## Requirements

| Tool | Where |
|------|--------|
| Android phone with HSR installed | — |
| PCAPdroid APK | [GitHub releases](https://github.com/emanuele-f/PCAPdroid/releases) |
| ADB (Android SDK Platform Tools) | `brew install --cask android-platform-tools` |
| Homebrew | [brew.sh](https://brew.sh) |
| Rust + libpcap | installed by `build_archiver.sh` |

---

## Quick start

### 1. Build reliquary-archiver

```bash
chmod +x scripts/build_archiver.sh
./scripts/build_archiver.sh
export PATH="$HOME/tools:$PATH"
```

### 2. Install PCAPdroid on your Android device

```bash
# Download latest APK
curl -L -o /tmp/PCAPdroid.apk \
  https://github.com/emanuele-f/PCAPdroid/releases/download/v1.9.1/PCAPdroid_v1.9.1.apk

# Install via ADB (USB debugging must be enabled)
adb install /tmp/PCAPdroid.apk
```

> **USB Install permission**: Settings → Developer Options → "Install via USB" must be ON.  
> If install fails with `INSTALL_FAILED_USER_RESTRICTED`, toggle that setting on the phone.

### 3. Capture game traffic

1. Open **PCAPdroid** on your phone
2. Tap the filter icon → **App filter** → select `崩坏：星穹铁道` (Honkai: Star Rail)
3. Tap **▶ START** — allow the VPN permission prompt
4. **Launch the game from scratch** (kill it first, then open fresh)
5. Wait until you reach the **main screen** (the star rail station)
6. Go back to PCAPdroid → **STOP**
7. Tap the capture record → **Download PCAP** → save to Downloads folder

> ⚠️ You must capture from **game launch**. The encryption key is negotiated at startup — if you start capturing after the game is already running, no data will be decoded.

### 4. Run the scanner

```bash
# Auto-detect latest pcap on connected device
./scripts/scan.sh

# Or use a local pcap file
./scripts/scan.sh /path/to/capture.pcap

# Specify ADB device serial (if multiple devices)
./scripts/scan.sh --device 22367202
```

Output: `hsr_output.json` containing all your relics, characters, and light cones.

---

## Output format

The output follows the [Fribbels HSR Optimizer](https://github.com/fribbels/hsr-optimizer) `KelzFormat` (same as reliquary-archiver's native output):

```jsonc
{
  "source": "reliquary_archiver",
  "version": 4,
  "characters": [
    {
      "id": "1223",
      "name": "Firefly",
      "level": 80,
      "eidolon": 0,
      "path": "Destruction",
      "skills": { "basic": 1, "skill": 10, "ult": 10, "talent": 10 },
      ...
    }
  ],
  "relics": [
    {
      "set_id": "118",
      "name": "Iron Cavalry Against the Scourge",
      "slot": "Head",
      "rarity": 5,
      "level": 15,
      "mainstat": "HP",
      "substats": [
        { "key": "CRIT Rate_", "value": 6.48, "count": 3, "step": 2 }
      ],
      "location": "1223",   // character id
      ...
    }
  ],
  "light_cones": [ ... ]
}
```

This JSON can also be fed into **[starrail-dashboard](https://github.com/ylongw/starrail-dashboard)** for a self-hosted account overview.

This JSON can be imported directly into [hsr-optimizer](https://fribbels.github.io/hsr-optimizer/) via **Import → Reliquary Archiver**.

---

## Manual pcap conversion

If you already have a pcap and just need to fix the LinkType:

```bash
python3 scripts/convert_pcap.py capture.pcap capture_eth.pcap
reliquary-archiver --pcap capture_eth.pcap output.json
```

---

## Why does the conversion fix work?

PCAPdroid routes traffic through Android's `VPNService` API using a TUN (tunnel) interface. Packets at this layer start directly with the IP header — there is no link-layer (Ethernet) framing. The pcap global header records **LinkType 101** to signal this.

`reliquary-archiver` (and most desktop packet analysis tools) expect **LinkType 1** — Ethernet-framed packets starting with a 14-byte `[dst MAC][src MAC][EtherType]` header.

The fix: prepend a fake 14-byte Ethernet header to every packet and update the pcap global header's LinkType field. The actual IP/UDP payload is unchanged; we're just adding the framing layer the parser expects.

```
Before:  [IP header][UDP header][encrypted payload]          LinkType=101
After:   [fake ETH 14B][IP header][UDP header][encrypted payload]  LinkType=1
```

This is a **known gap** in the reliquary-archiver documentation — it only mentions Windows usage. This repo fills that gap for Android + macOS users.

---

## Updating your inventory

Re-capture whenever you want fresh data (after pulling new relics, etc.):

```bash
# Kill the game, open it fresh, capture on PCAPdroid, then:
./scripts/scan.sh
```

---

## Credits

- [reliquary-archiver](https://github.com/IceDynamix/reliquary-archiver) by IceDynamix — the core parsing engine
- [PCAPdroid](https://github.com/emanuele-f/PCAPdroid) by emanuele-f — rootless Android packet capture
- HSR reverse engineering community for protobuf definitions

---

## License

MIT
