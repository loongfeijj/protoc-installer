# protoc-installer

A lightweight Bash script to install a specific version of [Protocol Buffers](https://github.com/protocolbuffers/protobuf) compiler (`protoc`) from official GitHub Releases.

No package manager required. Just `curl` and `bash`.

## Features

- **Version selection** — Install any available Protobuf release.
- **Cross-platform** — Supports Linux and macOS.
- **Architecture detection** — Automatically detects x86_64 and ARM64.
- **Custom installation path** — Configure the installation prefix with `PREFIX`.
- **Checksum verification** — Verifies SHA256 when the GitHub Release API provides a digest.
- **No root required** — Installs to `$HOME/.local` by default.
- **Minimal dependencies** — No `jq`, `wget`, or other third-party tools required.

## Quick Start

Install `protoc` with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/loongfeijj/protoc-installer/main/install_protoc.sh \
  | bash -s -- 3.19.4
```

This installs `protoc` into:

```text
$HOME/.local/bin/protoc
```

Verify the installation:

```bash
$HOME/.local/bin/protoc --version
```

Expected output:

```text
libprotoc 3.19.4
```

## Usage

### Install a specific version

```bash
./install_protoc.sh 3.19.4
```

The `v` prefix is optional:

```bash
./install_protoc.sh 21.12
./install_protoc.sh v21.12
```

### Custom installation directory

Use the `PREFIX` environment variable to specify the installation directory:

```bash
PREFIX="$HOME/.local" ./install_protoc.sh 3.19.4
```

Install system-wide:

```bash
sudo env PREFIX=/usr/local ./install_protoc.sh 3.19.4
```

### Require SHA256 verification

By default, the installer verifies SHA256 when a digest is available from GitHub Release metadata.

To require checksum verification:

```bash
REQUIRE_CHECKSUM=1 ./install_protoc.sh 3.19.4
```

The installation fails if no trusted SHA256 digest is available.

### Install directly using curl

Custom installation directory:

```bash
curl -fsSL https://raw.githubusercontent.com/loongfeijj/protoc-installer/main/install_protoc.sh \
  | PREFIX="$HOME/.local" bash -s -- 3.19.4
```

Require checksum verification:

```bash
curl -fsSL https://raw.githubusercontent.com/loongfeijj/protoc-installer/main/install_protoc.sh \
  | REQUIRE_CHECKSUM=1 bash -s -- 3.19.4
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `PREFIX` | `$HOME/.local` | Installation prefix |
| `PROTOC_SHA256` | Empty | Expected SHA256 checksum |
| `REQUIRE_CHECKSUM` | `0` | Require checksum verification (`1` or `0`) |

## Installation Layout

The installer extracts the official release archive and installs its contents:

```text
<PREFIX>/
├── bin/
│   └── protoc
└── include/
    └── google/
        └── protobuf/
            └── ...
```

Add the binary directory to your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

To make it persistent, add the command to `~/.bashrc` or `~/.zshrc`.

## Requirements

The following tools must be available:

- Bash
- curl
- unzip
- Python 3
- Standard Unix utilities (`uname`, `mktemp`, `sed`, `install`, `cp`)

## Supported Platforms

| Operating System | Architecture |
|---|---|
| Linux | x86_64 |
| Linux | ARM64 |
| macOS | x86_64 |
| macOS | ARM64 |

Availability depends on whether the corresponding binary archive exists in the requested upstream release.

## How It Works

1. Detect the operating system and CPU architecture.
2. Fetch release metadata from the official GitHub API.
3. Locate the matching `protoc` binary archive.
4. Download the official release archive.
5. Verify its SHA256 digest when available.
6. Extract the archive.
7. Install `protoc` and protobuf include files.
8. Verify the installed version.

All binary archives are downloaded from the official [Protocol Buffers GitHub Releases](https://github.com/protocolbuffers/protobuf/releases).

## Development

Check shell syntax:

```bash
bash -n install_protoc.sh
```

Run ShellCheck:

```bash
shellcheck install_protoc.sh
```

Run the installer locally:

```bash
./install_protoc.sh 3.19.4
```

## License

MIT
