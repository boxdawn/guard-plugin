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

VERSION=0.1.1
BUILD=4666fdedff080507736031eb9a472d7d76b15999
SUM_MACOS_ARM64=00024fce18a6ff45e2d29957209d974bca8a3b5cbfc0a0318b9ebbe0f222798e
SUM_MACOS_X64=cd296cbccc6849514ced8746cf36b9c61c067d3cf8db8025583e82068fcd7b95
SUM_LINUX_X64=12ead5e7970347f5d70e4dc4a26e3bb8a3b8f92840f12a495d92975536f55d86
SUM_LINUX_ARM64=c98f0405e893796d74fe1adafff869367af3da2357c7b19d7a39620fab455b14

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
