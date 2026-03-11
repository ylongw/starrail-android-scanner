#!/usr/bin/env bash
# build_archiver.sh — Compile reliquary-archiver on macOS (Apple Silicon / Intel)
#
# Installs dependencies via Homebrew and compiles with the `pcap` feature.
# Output binary: ~/tools/reliquary-archiver

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[build]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }
die()  { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

ARCHIVER_REPO="https://github.com/IceDynamix/reliquary-archiver"
ARCHIVER_TAG="v0.13.3"   # tested version; bump if needed
INSTALL_DIR="$HOME/tools"
BUILD_DIR="/tmp/reliquary-archiver-build"

# ── 1. Check / install dependencies ──────────────────────────────────────────
log "Checking dependencies..."

if ! command -v brew &>/dev/null; then
  die "Homebrew not found. Install from https://brew.sh first."
fi

for pkg in rust libpcap; do
  if ! brew list "$pkg" &>/dev/null; then
    log "Installing $pkg via Homebrew..."
    brew install "$pkg"
  else
    log "$pkg already installed"
  fi
done

# ── 2. Clone / update source ──────────────────────────────────────────────────
if [[ -d "$BUILD_DIR" ]]; then
  log "Updating existing clone..."
  git -C "$BUILD_DIR" fetch --tags
  git -C "$BUILD_DIR" checkout "$ARCHIVER_TAG" 2>/dev/null || \
    git -C "$BUILD_DIR" checkout "$(git -C "$BUILD_DIR" describe --tags --abbrev=0)"
else
  log "Cloning reliquary-archiver $ARCHIVER_TAG..."
  git clone --depth 1 --branch "$ARCHIVER_TAG" "$ARCHIVER_REPO" "$BUILD_DIR"
fi

# ── 3. Build ──────────────────────────────────────────────────────────────────
log "Compiling (this takes ~2-5 minutes on first run)..."

export PATH="/opt/homebrew/opt/rust/bin:$PATH"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libpcap/lib/pkgconfig"

cd "$BUILD_DIR"
cargo build --release --features pcap

# ── 4. Install ────────────────────────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
cp target/release/reliquary-archiver "$INSTALL_DIR/reliquary-archiver"
chmod +x "$INSTALL_DIR/reliquary-archiver"

log "Installed to $INSTALL_DIR/reliquary-archiver"
"$INSTALL_DIR/reliquary-archiver" --version 2>/dev/null || \
  log "(binary built successfully, --version not supported)"

echo -e "\n${GREEN}✅ Build complete!${NC}"
echo "   Run: export PATH=\"\$HOME/tools:\$PATH\""
echo "   Or:  ./scripts/scan.sh"
