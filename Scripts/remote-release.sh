#!/bin/bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir
project_dir="$(cd "$script_dir/.." && pwd)"
readonly project_dir
readonly config_file="${FRESH_PROFILE_REMOTE_CONFIG:-$project_dir/.local/remote-release.env}"

[[ -r "$config_file" ]] || {
  echo "Missing remote release configuration." >&2
  exit 1
}

# shellcheck disable=SC1090
source "$config_file"
: "${FRESH_MAC_HOST:?FRESH_MAC_HOST is required}"
: "${FRESH_MAC_SSH_KEY:?FRESH_MAC_SSH_KEY is required}"
: "${FRESH_MAC_PROJECT:?FRESH_MAC_PROJECT is required}"
: "${FRESH_MAC_HOME:?FRESH_MAC_HOME is required}"
: "${FRESH_MAC_GUI_UID:?FRESH_MAC_GUI_UID is required}"
: "${FRESH_MAC_XCODEGEN:?FRESH_MAC_XCODEGEN is required}"
FRESH_MAC_RCODESIGN="${FRESH_MAC_RCODESIGN:-$FRESH_MAC_HOME/Library/Application Support/FreshProfile/Tools/rcodesign}"

readonly ssh_options=(
  -i "$FRESH_MAC_SSH_KEY"
  -o BatchMode=yes
  -o ConnectTimeout=10
)
readonly launch_label="app.somtum.FreshProfile.release"
readonly launch_agent_source="$FRESH_MAC_PROJECT/Support/app.somtum.FreshProfile.release.plist"
readonly launch_agent_target="$FRESH_MAC_HOME/Library/LaunchAgents/app.somtum.FreshProfile.release.plist"
readonly result_file="/tmp/app.somtum.FreshProfile.release.result"
readonly log_file="$FRESH_MAC_HOME/Library/Logs/FreshProfile/release.out.log"
readonly error_log="$FRESH_MAC_HOME/Library/Logs/FreshProfile/release.err.log"

run_ssh() {
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" "$FRESH_MAC_HOST" "$@"
}

rsync -az --delete \
  --exclude .git/ \
  --exclude .build/ \
  --exclude .local/ \
  --exclude dist/ \
  --exclude FreshProfile.xcodeproj/ \
  -e "ssh -i $FRESH_MAC_SSH_KEY -o BatchMode=yes -o ConnectTimeout=10" \
  "$project_dir/" "$FRESH_MAC_HOST:$FRESH_MAC_PROJECT/"

run_ssh "/bin/mkdir -p '$FRESH_MAC_HOME/Library/LaunchAgents' '$FRESH_MAC_HOME/Library/Logs/FreshProfile'; /usr/bin/install -m 600 '$launch_agent_source' '$launch_agent_target'; /usr/bin/plutil -replace ProgramArguments.1 -string '$FRESH_MAC_PROJECT/Scripts/mac-release.sh' '$launch_agent_target'; /usr/bin/plutil -replace WorkingDirectory -string '$FRESH_MAC_PROJECT' '$launch_agent_target'; /usr/bin/plutil -replace StandardOutPath -string '$log_file' '$launch_agent_target'; /usr/bin/plutil -replace StandardErrorPath -string '$error_log' '$launch_agent_target'; /usr/bin/plutil -replace EnvironmentVariables.XCODEGEN_BIN -string '$FRESH_MAC_XCODEGEN' '$launch_agent_target'; /usr/bin/plutil -remove EnvironmentVariables.RCODESIGN_BIN '$launch_agent_target' >/dev/null 2>&1 || true; /usr/bin/plutil -replace EnvironmentVariables.FRESH_PROFILE_RCODESIGN_BIN -string '$FRESH_MAC_RCODESIGN' '$launch_agent_target'; /bin/rm -f '$result_file'; /bin/launchctl bootout 'gui/$FRESH_MAC_GUI_UID/$launch_label' >/dev/null 2>&1 || true; /bin/launchctl bootstrap 'gui/$FRESH_MAC_GUI_UID' '$launch_agent_target'; /bin/launchctl kickstart 'gui/$FRESH_MAC_GUI_UID/$launch_label'"

result=""
for _ in $(seq 1 360); do
  result="$(run_ssh "if [[ -f '$result_file' ]]; then /bin/cat '$result_file'; fi")"
  [[ -z "$result" ]] || break
  sleep 5
done

if [[ -z "$result" ]]; then
  echo "Timed out waiting for the macOS release build." >&2
  run_ssh "/usr/bin/tail -n 100 '$log_file'; /usr/bin/tail -n 100 '$error_log'"
  exit 124
fi

printf '%s\n' "$result"
exit_code="$(awk -F= '$1 == "exit_code" { print $2 }' <<<"$result")"
if [[ "$exit_code" != "0" ]]; then
  run_ssh "/usr/bin/tail -n 120 '$log_file'; /usr/bin/tail -n 120 '$error_log'"
  [[ "$exit_code" =~ ^[0-9]+$ ]] && exit "$exit_code"
  exit 1
fi

artifact_path="$(awk -F= '$1 == "artifact_path" { print $2 }' <<<"$result")"
checksum_path="$(awk -F= '$1 == "checksum_path" { print $2 }' <<<"$result")"
[[ -n "$artifact_path" && -n "$checksum_path" ]] || {
  echo "The remote build did not return artifact paths." >&2
  exit 1
}

mkdir -p "$project_dir/dist"
scp "${ssh_options[@]}" \
  "$FRESH_MAC_HOST:$artifact_path" \
  "$FRESH_MAC_HOST:$checksum_path" \
  "$project_dir/dist/"

echo "local_artifact=$project_dir/dist/$(basename "$artifact_path")"
echo "local_checksum=$project_dir/dist/$(basename "$checksum_path")"
