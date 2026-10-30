#!/usr/bin/env bash
#
# Install a specific version of Protocol Buffers compiler (protoc).
#
# Usage:
#   ./install_protoc.sh <version>
#
# Examples:
#   ./install_protoc.sh 3.19.4
#   ./install_protoc.sh 21.12
#   ./install_protoc.sh v21.12
#
# Environment variables:
#   PREFIX              Installation prefix (default: $HOME/.local)
#   PROTOC_SHA256       Expected SHA256 checksum (optional)
#   REQUIRE_CHECKSUM    Require checksum verification (default: 0)
#
# Example:
#   PREFIX=/usr/local sudo -E ./install_protoc.sh 3.19.4
#
# Requirements:
#   curl, unzip, python3
#

set -Eeuo pipefail

readonly REPO="protocolbuffers/protobuf"
readonly API_URL="https://api.github.com/repos/${REPO}/releases/tags"

PREFIX="${PREFIX:-${HOME}/.local}"
REQUIRE_CHECKSUM="${REQUIRE_CHECKSUM:-0}"

die() {
    echo "error: $*" >&2
    exit 1
}

log() {
    echo "[install-protoc] $*"
}

usage() {
    cat <<EOF
Usage: $0 <version>

Install a specific protoc version.

Examples:
  $0 3.19.4
  $0 21.12
  PREFIX=\$HOME/.local $0 3.19.4

Environment:
  PREFIX              Installation directory (default: \$HOME/.local)
  PROTOC_SHA256       Expected SHA256 checksum
  REQUIRE_CHECKSUM    Require checksum verification (default: 0)
EOF
    exit 1
}

# -------------------------------------------------------------------
# Check arguments and dependencies
# -------------------------------------------------------------------

[[ $# -eq 1 ]] || usage

VERSION="${1#v}"

[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)*([.-][0-9A-Za-z]+)*$ ]] \
    || die "Invalid version: $1"

for cmd in curl unzip python3; do
    command -v "$cmd" >/dev/null 2>&1 \
        || die "Required command not found: $cmd"
done

# -------------------------------------------------------------------
# Detect platform and architecture
# -------------------------------------------------------------------

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux)
        OS_NAME="linux"
        ;;
    Darwin)
        OS_NAME="osx"
        ;;
    *)
        die "Unsupported operating system: $OS"
        ;;
esac

case "$ARCH" in
    x86_64 | amd64)
        ARCH_NAME="x86_64"
        ;;
    aarch64 | arm64)
        ARCH_NAME="aarch_64"
        ;;
    *)
        die "Unsupported architecture: $ARCH"
        ;;
esac

ASSET="protoc-${VERSION}-${OS_NAME}-${ARCH_NAME}.zip"
TAG="v${VERSION}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

log "Version:      ${VERSION}"
log "Platform:     ${OS_NAME}-${ARCH_NAME}"
log "Install path: ${PREFIX}"

# -------------------------------------------------------------------
# Prepare temporary directory
# -------------------------------------------------------------------

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ZIP_FILE="${TMP_DIR}/${ASSET}"
API_FILE="${TMP_DIR}/release.json"
EXTRACT_DIR="${TMP_DIR}/extracted"

mkdir -p "$EXTRACT_DIR"

# -------------------------------------------------------------------
# Resolve release asset and checksum from GitHub API
# -------------------------------------------------------------------

log "Fetching release metadata..."

if ! curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "${API_URL}/${TAG}" \
    -o "$API_FILE"; then
    die "Failed to fetch release metadata: ${TAG}"
fi

ASSET_INFO="$(python3 - "$API_FILE" "$ASSET" <<'PY'
import json
import sys

path, name = sys.argv[1:]

with open(path, encoding="utf-8") as f:
    release = json.load(f)

for asset in release.get("assets", []):
    if asset.get("name") == name:
        print(asset["browser_download_url"])
        print(asset.get("digest") or "")
        sys.exit(0)

sys.exit(1)
PY
)" || die "Asset not found: ${ASSET}"

DOWNLOAD_URL="$(printf '%s\n' "$ASSET_INFO" | sed -n '1p')"
RELEASE_SHA256="$(printf '%s\n' "$ASSET_INFO" | sed -n '2p')"

# -------------------------------------------------------------------
# Download
# -------------------------------------------------------------------

log "Downloading ${ASSET}..."

curl -fL --retry 3 --retry-delay 2 \
    "$DOWNLOAD_URL" \
    -o "$ZIP_FILE"

[[ -s "$ZIP_FILE" ]] || die "Downloaded file is empty"

# -------------------------------------------------------------------
# Verify checksum
# -------------------------------------------------------------------

EXPECTED_SHA256="${PROTOC_SHA256:-}"

if [[ -n "$RELEASE_SHA256" ]]; then
    EXPECTED_SHA256="${RELEASE_SHA256#sha256:}"
fi

if [[ -n "${PROTOC_SHA256:-}" && -n "$RELEASE_SHA256" ]]; then
    [[ "${PROTOC_SHA256,,}" == "${RELEASE_SHA256#sha256:}" ]] \
        || die "PROTOC_SHA256 does not match GitHub release digest"
fi

if [[ -n "$EXPECTED_SHA256" ]]; then
    ACTUAL_SHA256="$(python3 - "$ZIP_FILE" <<'PY'
import hashlib
import sys

h = hashlib.sha256()
with open(sys.argv[1], "rb") as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b""):
        h.update(chunk)

print(h.hexdigest())
PY
)"

    [[ "${ACTUAL_SHA256,,}" == "${EXPECTED_SHA256,,}" ]] \
        || die "SHA256 checksum verification failed"

    log "SHA256 verification passed"
else
    if [[ "$REQUIRE_CHECKSUM" == "1" ]]; then
        die "No trusted SHA256 digest available for this release"
    fi

    log "WARNING: No SHA256 digest available; skipping verification"
fi

# -------------------------------------------------------------------
# Extract and validate
# -------------------------------------------------------------------

log "Extracting archive..."

unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"

[[ -f "${EXTRACT_DIR}/bin/protoc" ]] \
    || die "Invalid archive: bin/protoc not found"

[[ -x "${EXTRACT_DIR}/bin/protoc" ]] \
    || chmod +x "${EXTRACT_DIR}/bin/protoc"

# -------------------------------------------------------------------
# Install
# -------------------------------------------------------------------

log "Installing protoc..."

mkdir -p "${PREFIX}/bin" "${PREFIX}/include"

install -m 755 \
    "${EXTRACT_DIR}/bin/protoc" \
    "${PREFIX}/bin/protoc"

if [[ -d "${EXTRACT_DIR}/include" ]]; then
    cp -a "${EXTRACT_DIR}/include/." "${PREFIX}/include/"
fi

# -------------------------------------------------------------------
# Verify installation
# -------------------------------------------------------------------

INSTALLED_VERSION="$("${PREFIX}/bin/protoc" --version)"

log "Installation completed successfully"
log "Installed: ${PREFIX}/bin/protoc"
log "Version:   ${INSTALLED_VERSION}"

if [[ "${PREFIX}/bin" != *":${PATH}:"* ]] \
    && [[ ":${PATH}:" != *":${PREFIX}/bin:"* ]]; then
    log "Add the following to your shell configuration:"
    echo "export PATH=\"${PREFIX}/bin:\$PATH\""
fi
