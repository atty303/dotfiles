#!/bin/bash

set -euo pipefail

mode=$1
shift

runner_directory=$1
staging_directory=$2
recipient=$3
log_directory=$4
mise_for_cleanup=
trusted_config=

run_test() {
  local mise

  if [[ -x "$HOME/.local/bin/mise" ]]; then
    mise=$HOME/.local/bin/mise
  elif [[ -x /opt/homebrew/bin/mise ]]; then
    mise=/opt/homebrew/bin/mise
  elif mise=$(command -v mise); then
    :
  else
    echo "mise is not installed on the Mac host" >&2
    return 1
  fi

  export CHEZMOI_E2E_LOG_DIRECTORY=$log_directory

  cd "$runner_directory"
  mise_for_cleanup=$mise
  trusted_config=$runner_directory/mise.toml
  "$mise" trust "$trusted_config"
  "$mise" install
  "$mise" exec -- deno run -A tests/e2e/main.ts mac host "$staging_directory" "$recipient"
}

finish_run() {
  local status=$? status_tmp untrust_status=0

  trap - EXIT
  set +e
  if [[ -n $mise_for_cleanup && -n $trusted_config ]]; then
    "$mise_for_cleanup" trust --untrust "$trusted_config"
    untrust_status=$?
    if ((untrust_status != 0)); then
      echo "failed to remove mise trust for the temporary runner" >&2
    fi
  fi
  if ((status == 0 && untrust_status != 0)); then
    status=$untrust_status
  fi

  status_tmp="$result_file.tmp.$$"
  printf "%s\n" "$status" >"$status_tmp"
  /bin/mv -f "$status_tmp" "$result_file"
  exit "$status"
}

run_launch_agent() {
  local agent_status deadline label loaded plist result_file service_target startup_deadline uid

  uid=$(id -u)
  label="dev.chezmoi.e2e.macos.$$"
  plist=$log_directory/launch-agent.plist
  result_file=$log_directory/launch-agent.status
  service_target="gui/$uid/$label"
  loaded=false

  /usr/bin/plutil -create xml1 "$plist"
  /usr/bin/plutil -insert Label -string "$label" "$plist"
  /usr/bin/plutil -insert ProgramArguments -array "$plist"
  /usr/bin/plutil -insert ProgramArguments.0 -string /bin/bash "$plist"
  /usr/bin/plutil -insert ProgramArguments.1 -string "$runner_directory/tests/e2e/mac_remote.sh" "$plist"
  /usr/bin/plutil -insert ProgramArguments.2 -string run "$plist"
  /usr/bin/plutil -insert ProgramArguments.3 -string "$runner_directory" "$plist"
  /usr/bin/plutil -insert ProgramArguments.4 -string "$staging_directory" "$plist"
  /usr/bin/plutil -insert ProgramArguments.5 -string "$recipient" "$plist"
  /usr/bin/plutil -insert ProgramArguments.6 -string "$log_directory" "$plist"
  /usr/bin/plutil -insert ProgramArguments.7 -string "$result_file" "$plist"
  /usr/bin/plutil -insert ProcessType -string Interactive "$plist"
  /usr/bin/plutil -insert RunAtLoad -bool true "$plist"
  /usr/bin/plutil -insert StandardOutPath -string "$log_directory/host-stdout.log" "$plist"
  /usr/bin/plutil -insert StandardErrorPath -string "$log_directory/host-stderr.log" "$plist"

  cleanup() {
    if [[ $loaded == true ]]; then
      if /bin/launchctl bootout "$service_target" >/dev/null 2>&1 ||
        ! /bin/launchctl print "$service_target" >/dev/null 2>&1
      then
        loaded=false
      else
        echo "failed to remove macOS E2E LaunchAgent $service_target" >&2
        return 1
      fi
    fi
  }
  trap 'cleanup; exit 129' HUP
  trap 'cleanup; exit 130' INT
  trap 'cleanup; exit 143' TERM

  loaded=true
  if ! /bin/launchctl bootstrap "gui/$uid" "$plist"; then
    if ! cleanup; then
      return 1
    fi
    return 1
  fi
  startup_deadline=$((SECONDS + 30))
  deadline=$((SECONDS + 7800))
  while [[ ! -f $result_file ]]; do
    if ((SECONDS >= startup_deadline)) &&
      ! /bin/launchctl print "$service_target" 2>/dev/null | /usr/bin/grep -q 'state = running'
    then
      echo "macOS E2E LaunchAgent exited before reporting status" >&2
      cleanup
      return 1
    fi
    if ((SECONDS >= deadline)); then
      echo "macOS E2E LaunchAgent timed out" >&2
      cleanup
      return 124
    fi
    sleep 2
  done

  agent_status=$(<"$result_file")
  if [[ ! $agent_status =~ ^[0-9]+$ ]] || ((agent_status < 0 || agent_status > 255)); then
    echo "macOS E2E LaunchAgent reported an invalid status: $agent_status" >&2
    cleanup
    return 1
  fi
  if ! cleanup; then
    return 1
  fi
  return "$agent_status"
}

case $mode in
  launch)
    run_launch_agent
    ;;
  run)
    result_file=$5
    trap finish_run EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
    run_test
    ;;
  *)
    echo "usage: mac_remote.sh {launch|run} ..." >&2
    exit 2
    ;;
esac
