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

VERSION=0.4.17
BUILD=8f81b341161995ac691b64b07f4015858f19537f
SUM_MACOS_ARM64=05b70a4f2ef2289178eb6298d28635b0911d196e7988bafb8f5f531c09cb680a
SUM_MACOS_X64=4bab794dde2a3fa326d9acecfcb529e3dfa259d3833e1d8565c8fb514742a9b5
SUM_LINUX_X64=d36851279a389d580d5c823d6ad53ce0a8a51183f6c8b118b7e8c4ac0db4649f
SUM_LINUX_ARM64=84ff2c3e967a884c977c58e851b3fb8e61939f65fb2ffbd82f540e2ea4c22b4b

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
# A session opened before an update runs this script again from the older
# plugin folder. It must not put its older build over a newer one, so a build
# in place with a strictly newer VERSION is left alone.
ver_gt() {  # $1 is strictly newer than $2, both N.N.N
  case "$1$2" in *[!0-9.]*) return 1 ;; esac
  old_ifs=$IFS; IFS=.; set -- $1 $2; IFS=$old_ifs
  [ $# -eq 6 ] || return 1
  [ "$1" -gt "$4" ] || { [ "$1" -eq "$4" ] && { [ "$2" -gt "$5" ] || { [ "$2" -eq "$5" ] && [ "$3" -gt "$6" ]; }; }; }
}
keep=0
if [ -f "$dst/VERSION" ] && [ -x "$dst/bdxguard.exe" ] && ver_gt "$(cat "$dst/VERSION")" "$VERSION"; then
  keep=1
fi
if [ "$keep" -eq 0 ] && ! { [ -f "$dst/BUILD_ID" ] && [ "$(cat "$dst/BUILD_ID")" = "$BUILD" ]; }; then
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
