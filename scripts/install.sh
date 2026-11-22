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

VERSION=0.4.15
BUILD=c7b88abbebe2fd4d12e29969c73ab58a8bb5042c
SUM_MACOS_ARM64=97e8fe957949c9f93e37825322be1fdd7de250e6e61c30ccf9ac7a4a8a523aea
SUM_MACOS_X64=8a187290b49bcd8bd682cde426ab1f9a1e8a971ca84bdf86f48ab69ae321be5e
SUM_LINUX_X64=81b82e9f229b5fbae286dccc084290023150bea41ea70bddc0c8b9734332a4c7
SUM_LINUX_ARM64=19481558c786807b8e765daeb05344a091cab7f04549c843844a725cfaac9d10

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
