#!/usr/bin/env bash
# scan.sh — Full pipeline: Android → pcap → JSON
#
# Usage:
#   ./scripts/scan.sh                    # auto-detect pcap on device
#   ./scripts/scan.sh /path/to/file.pcap # use local pcap directly
#   ./scripts/scan.sh --device SERIAL    # specify ADB device serial
#
# Requirements:
#   - adb (Android SDK Platform Tools)
#   - reliquary-archiver binary (see README for build instructions)
#   - Python 3.x

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
ARCHIVER="${RELIQUARY_ARCHIVER:-$(command -v reliquary-archiver 2>/dev/null || echo "$HOME/tools/reliquary-archiver")}"
OUTPUT="${OUTPUT_JSON:-./hsr_output.json}"
ADB_DEVICE="${ADB_DEVICE:-}"
# ──────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[scan]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }
die()  { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

# Parse args
LOCAL_PCAP=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --device) ADB_DEVICE="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *.pcap)   LOCAL_PCAP="$1"; shift ;;
    *) warn "Unknown argument: $1"; shift ;;
  esac
done

# Check archiver
[[ -x "$ARCHIVER" ]] || die "reliquary-archiver not found at '$ARCHIVER'\nSee README for build instructions."

ADB_CMD="adb"
[[ -n "$ADB_DEVICE" ]] && ADB_CMD="adb -s $ADB_DEVICE"

# ── Step 1: Get pcap ──────────────────────────────────────────────────────────
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ -n "$LOCAL_PCAP" ]]; then
  log "Using local pcap: $LOCAL_PCAP"
  RAW_PCAP="$LOCAL_PCAP"
else
  log "Looking for PCAPdroid captures on device..."

  # PCAPdroid saves to /sdcard/Download/PCAPdroid/ (user-selected location)
  DEVICE_PCAP=$($ADB_CMD shell "ls -t /sdcard/Download/PCAPdroid/*.pcap 2>/dev/null | head -1" | tr -d '\r')

  if [[ -z "$DEVICE_PCAP" ]]; then
    die "No pcap found on device at /sdcard/Download/PCAPdroid/\n" \
        "Please capture traffic with PCAPdroid first (see README), " \
        "then export as PCAP to Downloads."
  fi

  log "Found: $DEVICE_PCAP"
  RAW_PCAP="$WORK_DIR/raw.pcap"
  log "Pulling from device..."
  $ADB_CMD pull "$DEVICE_PCAP" "$RAW_PCAP"
  log "Pulled $(du -h "$RAW_PCAP" | cut -f1)"
fi

# ── Step 2: Convert LinkType 101 → 1 ─────────────────────────────────────────
log "Converting pcap LinkType (Raw IP → Ethernet)..."
ETH_PCAP="$WORK_DIR/eth.pcap"
python3 "$SCRIPT_DIR/convert_pcap.py" "$RAW_PCAP" "$ETH_PCAP"

# ── Step 3: Parse with reliquary-archiver ────────────────────────────────────
log "Parsing game data with reliquary-archiver..."
"$ARCHIVER" --pcap "$ETH_PCAP" "$OUTPUT" 2>&1 | grep -E "(INFO|WARN|ERROR)" || true

# ── Step 4: Summary ───────────────────────────────────────────────────────────
if [[ -f "$OUTPUT" ]]; then
  python3 - "$OUTPUT" << 'PY'
import json, sys
with open(sys.argv[1]) as f: d = json.load(f)
chars   = len(d.get('characters', []))
relics  = len(d.get('relics', []))
lcs     = len(d.get('light_cones', []))
print(f"\n✅ Success!")
print(f"   Characters : {chars}")
print(f"   Relics     : {relics}")
print(f"   Light cones: {lcs}")
print(f"   Output     : {sys.argv[1]}")
PY
else
  die "Output file was not created. Check the logs above."
fi
