#!/bin/zsh

set -euo pipefail

readonly version="0.29.0"
readonly archive_name="apple-codesign-$version-macos-universal.tar.gz"
readonly archive_url="https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign%2F$version/$archive_name"
readonly expected_sha256="d98372d5524226ccf9dc0eda03d4e4f5826182dabb2fc3f2bd303ed9113a748d"
readonly install_root="${FRESH_PROFILE_RCODESIGN_INSTALL_ROOT:-$HOME/Library/Application Support/FreshProfile/Tools}"
readonly work_dir="$(/usr/bin/mktemp -d /tmp/FreshProfile-rcodesign.XXXXXX)"
readonly archive_path="$work_dir/$archive_name"

cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT

/usr/bin/curl \
  --fail \
  --location \
  --retry 3 \
  --output "$archive_path" \
  "$archive_url"

readonly actual_sha256="$(
  /usr/bin/shasum -a 256 "$archive_path" | /usr/bin/awk '{ print $1 }'
)"

[[ "$actual_sha256" == "$expected_sha256" ]] || {
  print -u2 "rcodesign archive checksum mismatch."
  exit 1
}

/usr/bin/tar -xzf "$archive_path" -C "$work_dir"
readonly binary_path="$(
  /usr/bin/find "$work_dir" -type f -name rcodesign | /usr/bin/head -n 1
)"

[[ -n "$binary_path" ]] || {
  print -u2 "The rcodesign binary was not found in the archive."
  exit 1
}

/bin/mkdir -p "$install_root"
/usr/bin/install -m 755 "$binary_path" "$install_root/rcodesign"
"$install_root/rcodesign" --version
