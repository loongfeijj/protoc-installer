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
#   GITHUB_MIRROR       GitHub download URL prefix (default: https://github.com)
#   PROTOC_SHA256       Expected SHA256 checksum (optional)
#   REQUIRE_CHECKSUM    Require checksum verification (default: 0)
#
# Requirements:
#   bash, curl or wget, unzip, sha256sum or shasum
#

set -Eeuo pipefail

PREFIX="${PREFIX:-${HOME}/.local}"
GITHUB_MIRROR="${GITHUB_MIRROR:-https://github.com}"
REQUIRE_CHECKSUM="${REQUIRE_CHECKSUM:-0}"
PROTOC_SHA256="${PROTOC_SHA256:-}"

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
  GITHUB_MIRROR       GitHub URL prefix (default: https://github.com)
  PROTOC_SHA256       Expected SHA256 checksum (optional)
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

command -v curl >/dev/null 2>&1 \
    || command -v wget >/dev/null 2>&1 \
    || die "curl or wget is required"

command -v unzip >/dev/null 2>&1 \
    || die "unzip is required"

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

# -------------------------------------------------------------------
# Build official release URL
# -------------------------------------------------------------------

ASSET="protoc-${VERSION}-${OS_NAME}-${ARCH_NAME}.zip"

DOWNLOAD_URL="${GITHUB_MIRROR%/}/protocolbuffers/protobuf/releases/download/v${VERSION}/${ASSET}"

log "Version:      ${VERSION}"
log "Platform:     ${OS_NAME}-${ARCH_NAME}"
log "Install path: ${PREFIX}"
log "Download URL: ${DOWNLOAD_URL}"

# -------------------------------------------------------------------
# Prepare temporary directory
# -------------------------------------------------------------------

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ZIP_FILE="${TMP_DIR}/${ASSET}"
EXTRACT_DIR="${TMP_DIR}/extracted"

mkdir -p "$EXTRACT_DIR"

# -------------------------------------------------------------------
# Download
# -------------------------------------------------------------------

log "Downloading ${ASSET}..."

if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --retry-delay 2 \
        --connect-timeout 20 \
        "$DOWNLOAD_URL" \
        -o "$ZIP_FILE" \
        || die "Failed to download ${ASSET}"
else
    wget -q --tries=3 \
        -O "$ZIP_FILE" \
        "$DOWNLOAD_URL" \
        || die "Failed to download ${ASSET}"
fi

[[ -s "$ZIP_FILE" ]] || die "Downloaded file is empty"

# -------------------------------------------------------------------
# Verify SHA256
# -------------------------------------------------------------------

if [[ -n "$PROTOC_SHA256" ]]; then
    [[ "$PROTOC_SHA256" =~ ^[a-fA-F0-9]{64}$ ]] \
        || die "Invalid PROTOC_SHA256"

    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL_SHA256="$(sha256sum "$ZIP_FILE" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
        ACTUAL_SHA256="$(shasum -a 256 "$ZIP_FILE" | awk '{print $1}')"
    else
        die "sha256sum or shasum is required for checksum verification"
    fi

    EXPECTED_SHA256="$(printf '%s' "$PROTOC_SHA256" | tr 'A-F' 'a-f')"
    ACTUAL_SHA256="$(printf '%s' "$ACTUAL_SHA256" | tr 'A-F' 'a-f')"

    [[ "$ACTUAL_SHA256" == "$EXPECTED_SHA256" ]] \
        || die "SHA256 checksum verification failed"

    log "SHA256 verification passed"
else
    if [[ "$REQUIRE_CHECKSUM" == "1" ]]; then
        die "PROTOC_SHA256 is required when REQUIRE_CHECKSUM=1"
    fi

    log "WARNING: SHA256 verification skipped"
fi

# -------------------------------------------------------------------
# Extract and validate
# -------------------------------------------------------------------

log "Extracting archive..."

unzip -tq "$ZIP_FILE" \
    || die "Invalid or corrupted archive"

unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"

PROTOC_BIN="${EXTRACT_DIR}/bin/protoc"

[[ -f "$PROTOC_BIN" ]] \
    || die "Invalid archive: bin/protoc not found"

chmod +x "$PROTOC_BIN"

# -------------------------------------------------------------------
# Install
# -------------------------------------------------------------------

log "Installing protoc..."

mkdir -p "${PREFIX}/bin" "${PREFIX}/include"

install -m 755 "$PROTOC_BIN" "${PREFIX}/bin/protoc"

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

case ":${PATH}:" in
    *":${PREFIX}/bin:"*)
        ;;
    *)
        log "Add the following to your shell configuration:"
        echo "export PATH=\"${PREFIX}/bin:\$PATH\""
        ;;
esac
