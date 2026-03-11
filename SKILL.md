# starrail-android-scanner Skill

Export your Honkai: Star Rail relic inventory, characters, and light cones from an Android device to macOS — no root required.

## Prerequisites

- Android phone with HSR installed and USB debugging enabled
- ADB: `brew install --cask android-platform-tools`
- reliquary-archiver built: run `./scripts/build_archiver.sh` once
- PCAPdroid installed on phone: `adb install /tmp/PCAPdroid.apk`

## Usage

### First-time setup
```
Build reliquary-archiver for macOS
```

### Capture and scan
1. Open PCAPdroid on phone → filter to HSR app → tap START
2. Launch the game fresh (kill first), wait for main screen
3. Stop PCAPdroid → export PCAP to Downloads folder
4. Run:

```bash
./scripts/scan.sh                    # auto-detect pcap on device
./scripts/scan.sh /path/to/file.pcap # use local pcap
./scripts/scan.sh --device SERIAL    # specify ADB serial
```

Output: `hsr_output.json` (Fribbels KelzFormat v4, importable to hsr-optimizer)

### Fix existing pcap (LinkType issue)
```bash
python3 scripts/convert_pcap.py input.pcap output_eth.pcap
```

## How it works

PCAPdroid captures HSR's UDP traffic via Android VPNService (no root).
The capture has LinkType 101 (Raw IP) — `convert_pcap.py` patches it to
LinkType 1 (Ethernet) so reliquary-archiver can parse the encryption
key handshake and decrypt the protobuf inventory payloads.

## Files

- `scripts/convert_pcap.py` — pcap LinkType 101→1 converter
- `scripts/scan.sh` — full pipeline orchestrator
- `scripts/build_archiver.sh` — macOS build helper for reliquary-archiver
