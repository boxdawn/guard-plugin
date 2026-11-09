#!/bin/sh
# SessionStart on macOS and Linux: put this machine's guard build at
# ${CLAUDE_PLUGIN_DATA}/current/bdxguard.exe, the one path the PreToolUse hook
# runs on every OS (Unix ignores the extension).
#
# The build is downloaded once per version from the boxdawn/guard GitHub
# release named below, and used only if its sha256 matches the value pinned
# here. Until it is in place the hook cannot start, and onFailure "block"
# stops the command: no download, no commands.
set -eu

VERSION=0.4.6
BUILD=20845de9a62bc4eba368f18bf0e9c47bf1bb2220
SUM_MACOS_ARM64=5c870b8a39ac37ed1bb892a37d2cab1cddb831538f4ff8ee3a9d0dca35217b5c
SUM_MACOS_X64=b17e2a242c9c425b62f3baa7777c7876fe7afbfa8d1c95788d0aa9e4072d6a28
SUM_LINUX_X64=e4f0566fc22322d8130241a420816d8b3bc725737bd27bedabad4ccdae3d8d0f
SUM_LINUX_ARM64=f7d555c16b208f3a22dd99311db7d93be31354e992644c65b0852155ae3983bc

case "$(uname -s)" in
  Darwin) os=macos ;;
  Linux) os=linux ;;
  *) exit 0 ;;  # Windows, including Git Bash: install.ps1 does it
esac
case "$(uname -m)" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64) arch=x64 ;;
  *) echo "boxdawn guard: no build for $(uname -m)" >&2; exit 1 ;;
esac
case "$os-$arch" in
  macos-arm64) want=$SUM_MACOS_ARM64 ;;
  macos-x64) want=$SUM_MACOS_X64 ;;
  linux-x64) want=$SUM_LINUX_X64 ;;
  linux-arm64) want=$SUM_LINUX_ARM64 ;;
esac

dst="$CLAUDE_PLUGIN_DATA/current"
if ! { [ -f "$dst/BUILD_ID" ] && [ "$(cat "$dst/BUILD_ID")" = "$BUILD" ]; }; then
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  tmp=$(mktemp -d "$CLAUDE_PLUGIN_DATA/download.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
  url="https://github.com/boxdawn/guard/releases/download/v$VERSION/bdxguard-$os-$arch.tar.gz"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --proto '=https' --tlsv1.2 --retry 2 -o "$tmp/build.tar.gz" "$url"
  else
    wget -q --https-only -O "$tmp/build.tar.gz" "$url"
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    got=$(sha256sum "$tmp/build.tar.gz" | cut -d' ' -f1)
  else
    got=$(shasum -a 256 "$tmp/build.tar.gz" | cut -d' ' -f1)
  fi
  if [ "$got" != "$want" ]; then
    echo "boxdawn guard: downloaded build does not match its pinned sha256; not installed" >&2
    exit 1
  fi
  mkdir "$tmp/build"
  tar -xzf "$tmp/build.tar.gz" -C "$tmp/build"
  [ "$(cat "$tmp/build/BUILD_ID")" = "$BUILD" ] || { echo "boxdawn guard: unexpected build id" >&2; exit 1; }
  mv "$tmp/build/bdxguard" "$tmp/build/bdxguard.exe"
  chmod +x "$tmp/build/bdxguard.exe"
  rm -rf "$dst.old"
  if [ -d "$dst" ]; then mv "$dst" "$dst.old"; fi
  mv "$tmp/build" "$dst"
  rm -rf "$dst.old"
fi

# With an API key in the plugin's settings, fetch the signed rules in the
# background (the session does not wait). Without one this opens no connection.
if [ -n "${CLAUDE_PLUGIN_OPTION_API_KEY:-}" ]; then
  nohup "$dst/bdxguard.exe" fetch-rules </dev/null >/dev/null 2>&1 &
fi
