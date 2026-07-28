#!/bin/zsh

set -euo pipefail

readonly project_dir="${0:A:h:h}"
readonly config_path="${FRESH_PROFILE_ASC_CONFIG:-$HOME/Library/Application Support/PeCaViewer/AppStoreConnect.plist}"
readonly xcodegen_bin="${XCODEGEN_BIN:-$(command -v xcodegen || true)}"
readonly rcodesign_bin="${FRESH_PROFILE_RCODESIGN_BIN:-$HOME/Library/Application Support/FreshProfile/Tools/rcodesign}"
readonly output_root="$HOME/Library/Developer/FreshProfile/Releases"
readonly result_file="${FRESH_PROFILE_RESULT_FILE:-/tmp/app.somtum.FreshProfile.release.result}"

version=""
artifact_path=""
checksum_path=""

finish() {
  local exit_code=$?
  trap - EXIT
  {
    print "exit_code=$exit_code"
    print "version=$version"
    print "artifact_path=$artifact_path"
    print "checksum_path=$checksum_path"
  } > "$result_file"
  exit "$exit_code"
}
trap finish EXIT

[[ -x "$xcodegen_bin" ]] || {
  print -u2 "XcodeGen was not found. Set XCODEGEN_BIN."
  exit 1
}

[[ -x "$rcodesign_bin" ]] || {
  print -u2 "rcodesign was not found. Set FRESH_PROFILE_RCODESIGN_BIN."
  exit 1
}

[[ -r "$config_path" ]] || {
  print -u2 "Missing App Store Connect configuration."
  exit 1
}

[[ "$(/usr/bin/stat -f '%Lp' "$config_path")" == "600" ]] || {
  print -u2 "App Store Connect configuration must have mode 600."
  exit 1
}

readonly key_id="$(/usr/bin/plutil -extract keyID raw -o - "$config_path")"
readonly issuer_id="$(/usr/bin/plutil -extract issuerID raw -o - "$config_path")"
readonly key_path="$(/usr/bin/plutil -extract keyPath raw -o - "$config_path")"
readonly team_id="$(/usr/bin/plutil -extract teamID raw -o - "$config_path")"

[[ -r "$key_path" ]] || {
  print -u2 "The App Store Connect private key is missing."
  exit 1
}

version="$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$project_dir/Support/Info.plist")"
/bin/mkdir -p "$output_root"
readonly run_root="$(/usr/bin/mktemp -d "$output_root/run.XXXXXX")"
readonly archive_path="$run_root/FreshProfile.xcarchive"
readonly export_path="$run_root/export"
readonly submission_path="$run_root/FreshProfile-notarization.zip"
readonly notary_result="$run_root/notary-result.json"
artifact_path="$run_root/FreshProfile-$version-macos-universal.zip"
checksum_path="$artifact_path.sha256"

cd "$project_dir"
"$xcodegen_bin" generate

/usr/bin/xcodebuild archive \
  -project FreshProfile.xcodeproj \
  -scheme FreshProfile \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$key_path" \
  -authenticationKeyID "$key_id" \
  -authenticationKeyIssuerID "$issuer_id" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$team_id"

readonly app_path="$export_path/FreshProfile.app"
readonly executable_path="$app_path/Contents/MacOS/FreshProfile"
readonly archived_app_path="$archive_path/Products/Applications/FreshProfile.app"
readonly signing_key_path="$HOME/Library/Application Support/FreshProfile/DeveloperID-FreshProfile.key"
readonly certificate_path="$run_root/DeveloperIDApplication.pem"

[[ -r "$signing_key_path" ]] || {
  print -u2 "The Developer ID private key is missing."
  exit 1
}

/usr/bin/security find-certificate \
  -c "Developer ID Application:" \
  -p > "$certificate_path"

/bin/mkdir -p "$export_path"
"$rcodesign_bin" sign \
  --for-notarization \
  --pem-file "$signing_key_path" \
  --pem-file "$certificate_path" \
  "$archived_app_path" \
  "$app_path"

[[ -d "$app_path" && -x "$executable_path" ]] || {
  print -u2 "The exported app is missing."
  exit 1
}

/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"
/usr/bin/codesign -dv --verbose=4 "$app_path" 2>&1 \
  | /usr/bin/grep '^Authority=Developer ID Application:' >/dev/null
/usr/bin/lipo "$executable_path" -verify_arch arm64 x86_64

/usr/bin/ditto -c -k --keepParent "$app_path" "$submission_path"
/usr/bin/xcrun notarytool submit "$submission_path" \
  --key "$key_path" \
  --key-id "$key_id" \
  --issuer "$issuer_id" \
  --wait \
  --output-format json > "$notary_result"

[[ "$(/usr/bin/plutil -extract status raw -o - "$notary_result")" == "Accepted" ]] || {
  /bin/cat "$notary_result"
  exit 1
}

/usr/bin/xcrun stapler staple "$app_path"
/usr/bin/xcrun stapler validate "$app_path"
/usr/sbin/spctl --assess --type execute --verbose=4 "$app_path"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_path"

/usr/bin/ditto -c -k --keepParent "$app_path" "$artifact_path"
(
  cd "$run_root"
  /usr/bin/shasum -a 256 "${artifact_path:t}" > "${checksum_path:t}"
)

print "version=$version"
print "artifact_path=$artifact_path"
print "checksum_path=$checksum_path"
