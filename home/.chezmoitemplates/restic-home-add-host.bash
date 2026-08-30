readonly add_host_default_backup_calendar={{ .restic.defaults.backup_calendar | quote }}
readonly add_host_default_maintenance_calendar={{ .restic.defaults.maintenance_calendar | quote }}
readonly add_host_default_check_calendar={{ .restic.defaults.check_calendar | quote }}
readonly add_host_success_limit=20
readonly add_host_failure_limit=50

add_host_recording=true
add_host_recording_warned=false
add_host_run_id=""
add_host_started_at=""
add_host_phase=preflight
add_host_error_type=internal_error
add_host_record_dir=""
add_host_pending_record=""
add_host_prompted_calendar=""
add_host_timers_already_active=false
add_host_temp_files=()
add_host_temp_dirs=()

add_host_warn_recording() {
  if [[ $add_host_recording_warned == false ]]; then
    printf 'warning: restic-home add-host diagnostic recording is unavailable\n' >&2
    add_host_recording_warned=true
  fi
  add_host_recording=false
}

add_host_write_record() {
  local completeness=$1 status=$2 error_type=$3 target=$4 temporary_record
  [[ $add_host_recording == true ]] || return 0
  temporary_record="$add_host_record_dir/.record.$add_host_run_id.$$"
  if ! {
    umask 077
    printf '%s\n' \
      'schema_version=1' \
      "run_id=$add_host_run_id" \
      'resource=restic-home' \
      'operation=add-host' \
      "host=$host" \
      "started_at=$add_host_started_at" \
      "ended_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "phase=$add_host_phase" \
      "status=$status" \
      "error_type=$error_type" \
      "completeness=$completeness" >"$temporary_record" &&
      mv -f -- "$temporary_record" "$target"
  }; then
    rm -f -- "$temporary_record" 2>/dev/null || true
    add_host_warn_recording
  fi
}

add_host_prune_records() {
  local suffix limit records remove_count
  [[ $add_host_recording == true ]] || return 0
  for suffix in success failure; do
    (
      shopt -s nullglob
      if [[ $suffix == success ]]; then
        limit=$add_host_success_limit
        records=("$add_host_record_dir"/*.success)
      else
        limit=$add_host_failure_limit
        records=("$add_host_record_dir"/*.failure)
      fi
      remove_count=$((${#records[@]} - limit))
      if ((remove_count > 0)); then
        rm -f -- "${records[@]:0:remove_count}"
      fi
    ) || add_host_warn_recording
  done
}

add_host_initialize_recording() {
  add_host_run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  add_host_started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ ${RESTIC_HOME_ADD_HOST_RECORDING:-on} == off ]]; then
    add_host_recording=false
    return 0
  fi
  add_host_record_dir="${XDG_STATE_HOME:-$HOME/.local/state}/restic-home/add-host-runs"
  if ! mkdir -p -- "$add_host_record_dir" 2>/dev/null ||
    ! chmod 700 -- "$add_host_record_dir" 2>/dev/null; then
    add_host_warn_recording
    return 0
  fi
  add_host_pending_record="$add_host_record_dir/$add_host_run_id.pending"
  add_host_write_record partial pending "" "$add_host_pending_record"
}

add_host_set_phase() {
  add_host_phase=$1
  add_host_error_type=$2
  add_host_write_record partial pending "" "$add_host_pending_record"
}

add_host_finalize_recording() {
  local status=$1 final_status suffix error_type final_record
  [[ $add_host_recording == true ]] || return 0
  if ((status == 0)); then
    final_status=success
    suffix=success
    error_type=""
  elif ((status == 130)) || [[ $add_host_error_type == cancelled ]]; then
    final_status=cancel
    suffix=failure
    error_type=cancelled
  else
    final_status=error
    suffix=failure
    error_type=$add_host_error_type
  fi
  final_record="$add_host_record_dir/$add_host_run_id.$suffix"
  add_host_write_record complete "$final_status" "$error_type" "$final_record"
  if [[ $add_host_recording == true ]] && ! rm -f -- "$add_host_pending_record"; then
    add_host_warn_recording
  fi
  add_host_prune_records
}

add_host_cleanup() {
  local path status=0
  for path in "${add_host_temp_files[@]}"; do
    if [[ -n $path ]] && ! rm -f -- "$path" 2>/dev/null; then
      status=1
    fi
  done
  for path in "${add_host_temp_dirs[@]}"; do
    if [[ -n $path ]] && ! rm -rf -- "$path" 2>/dev/null; then
      status=1
    fi
  done
  if ((status == 0)); then
    add_host_temp_files=()
    add_host_temp_dirs=()
  fi
  return "$status"
}

add_host_cancel() {
  add_host_error_type=cancelled
  exit 130
}

add_host_finish() {
  local status=$?
  trap - EXIT INT TERM
  set +e
  if ! add_host_cleanup; then
    printf '%s\n' \
      'warning: temporary Restic output or restored content may remain; inspect the system temporary directory and remove restic-home add-host artifacts' >&2
  fi
  add_host_finalize_recording "$status"
  if ((status != 0)) && [[ $add_host_recording == true ]]; then
    printf 'Diagnostic run: %s\n' "$add_host_run_id" >&2
  fi
  exit "$status"
}

add_host_fail() {
  add_host_error_type=$1
  shift
  printf '%s\n' "$*" >&2
  return 1
}

add_host_require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    add_host_fail dependency_missing "restic-home add-host requires command: $1"
}

add_host_template_value() {
  local template=$1 open='{' close='}'
  open+='{'
  close+='}'
  template=${template//\[\[/$open}
  template=${template//\]\]/$close}
  chezmoi execute-template "$template"
}

add_host_confirm() {
  gum confirm "$1" || add_host_fail cancelled 'restic-home add-host cancelled'
}

add_host_prompt_calendar() {
  local label=$1 default_value=$2 value
  value=$(gum input --header "$label" --value "$default_value") ||
    add_host_fail cancelled 'restic-home add-host cancelled'
  [[ -n $value ]] || add_host_fail configuration_invalid "$label cannot be empty"
  systemd-analyze calendar "$value" >/dev/null ||
    add_host_fail configuration_invalid "invalid systemd calendar for $label: $value"
  add_host_prompted_calendar=$value
}

add_host_preserve_temp_file() {
  local preserved=$1 index
  for index in "${!add_host_temp_files[@]}"; do
    if [[ ${add_host_temp_files[$index]} == "$preserved" ]]; then
      add_host_temp_files[$index]=""
    fi
  done
}

add_host_restore_exchanged_source() {
  local source_file=$1 displaced_file=$2 prepared_file=$3 error_type=$4 message=$5
  if ! cmp -s -- "$prepared_file" "$source_file"; then
    add_host_preserve_temp_file "$displaced_file"
    add_host_fail source_conflict \
      "restic.toml changed after candidate publication; displaced content was preserved at $displaced_file"
    return 1
  fi
  if ! mv --exchange --no-copy -- "$displaced_file" "$source_file"; then
    add_host_preserve_temp_file "$displaced_file"
    add_host_fail source_recovery_required \
      "restic.toml could not be restored atomically; displaced content was preserved at $displaced_file"
    return 1
  fi
  add_host_fail "$error_type" "$message"
  return 1
}

add_host_append_source() {
  local source_file=$1 backup_calendar=$2 maintenance_calendar=$3 check_calendar=$4
  local source_dir original candidate prepared rendered_enabled
  source_dir=$(dirname -- "$source_file")
  exec 9<"$source_dir"
  flock -n 9 ||
    add_host_fail source_conflict 'another restic-home add-host source update is in progress'
  original=$(mktemp "$source_dir/.restic.toml.original.XXXXXX")
  candidate=$(mktemp "$source_dir/.restic.toml.candidate.XXXXXX")
  prepared=$(mktemp "$source_dir/.restic.toml.prepared.XXXXXX")
  add_host_temp_files+=("$original" "$candidate" "$prepared")
  cp -p -- "$source_file" "$original"
  cp -p -- "$source_file" "$candidate"
  printf '\n[restic.hosts."%s"]\nenabled = true\nbackup_calendar = "%s"\nmaintenance_calendar = "%s"\ncheck_calendar = "%s"\n' \
    "$host" "$backup_calendar" "$maintenance_calendar" "$check_calendar" >>"$candidate"
  taplo lint "$candidate"
  cmp -s -- "$original" "$source_file" ||
    add_host_fail source_conflict 'restic.toml changed while restic-home add-host was running'
  chmod --reference="$source_file" "$candidate"
  cp -p -- "$candidate" "$prepared"
  mv --exchange --no-copy -- "$candidate" "$source_file" ||
    add_host_fail source_update_failed 'restic.toml does not support atomic candidate exchange'
  if ! cmp -s -- "$original" "$candidate"; then
    add_host_restore_exchanged_source "$source_file" "$candidate" "$prepared" \
      source_conflict 'restic.toml changed while restic-home add-host was running'
    return 1
  fi
  if ! rendered_enabled=$(add_host_template_value '[[ if and (hasKey .restic.hosts .chezmoi.hostname) (index .restic.hosts .chezmoi.hostname).enabled ]]true[[ else ]]false[[ end ]]') ||
    [[ $rendered_enabled != true ]]; then
    add_host_restore_exchanged_source "$source_file" "$candidate" "$prepared" \
      source_update_failed 'new restic host entry could not be rendered; restored restic.toml'
    return 1
  fi
  rm -f -- "$original" "$candidate" "$prepared"
  flock -u 9
  exec 9>&-
}

add_host_apply_targets() {
  local directory directories=(
    "$HOME/.config"
    "$HOME/.config/restic"
    "$HOME/.local"
    "$HOME/.local/bin"
    "$HOME/.config/systemd"
    "$HOME/.config/systemd/user"
  )
  local targets=(
    "$HOME/.config/restic/b2.env"
    "$HOME/.config/restic/excludes"
    "$HOME/.local/bin/restic-home"
    "$HOME/.config/systemd/user/restic-backup.service"
    "$HOME/.config/systemd/user/restic-backup.timer"
    "$HOME/.config/systemd/user/restic-check.service"
    "$HOME/.config/systemd/user/restic-check.timer"
    "$HOME/.config/systemd/user/restic-failure-notify@.service"
    "$HOME/.config/systemd/user/restic-maintenance.service"
    "$HOME/.config/systemd/user/restic-maintenance.timer"
  )
  for directory in "${directories[@]}"; do
    if [[ ! -d $directory ]]; then
      chezmoi apply --include=dirs --verbose "$directory"
    fi
  done
  chezmoi apply --include=files --verbose "${targets[@]}"
}

add_host_timer_state() {
  local timer active enabled active_count=0 enabled_count=0
  for timer in restic-backup.timer restic-maintenance.timer restic-check.timer; do
    active=$(systemctl --user is-active "$timer" 2>/dev/null || true)
    enabled=$(systemctl --user is-enabled "$timer" 2>/dev/null || true)
    [[ $active == active ]] && ((active_count += 1))
    [[ $enabled == enabled ]] && ((enabled_count += 1))
    case $active in
      active | inactive) ;;
      *)
        add_host_fail timer_state_invalid "unexpected active state for $timer: $active"
        return 1
        ;;
    esac
    case $enabled in
      enabled | disabled) ;;
      *)
        add_host_fail timer_state_invalid "unexpected enabled state for $timer: $enabled"
        return 1
        ;;
    esac
  done
  if ((active_count == 3 && enabled_count == 3)); then
    add_host_timers_already_active=true
    return 0
  fi
  if ((active_count != 0 || enabled_count != 0)); then
    add_host_fail timer_state_invalid 'restic timer state is mixed; resolve it before onboarding'
    return 1
  fi
  add_host_timers_already_active=false
  return 0
}

add_host_verify_services_inactive() {
  local service state
  for service in restic-backup.service restic-maintenance.service restic-check.service; do
    state=$(systemctl --user is-active "$service" 2>/dev/null || true)
    [[ $state == inactive ]] ||
      add_host_fail service_active "restic service is not inactive: $service ($state)"
  done
}

add_host_rollback_timers() {
  local timer active enabled rollback_failed=false
  if ! systemctl --user disable --now \
    restic-backup.timer restic-maintenance.timer restic-check.timer >/dev/null 2>&1; then
    rollback_failed=true
  fi
  for timer in restic-backup.timer restic-maintenance.timer restic-check.timer; do
    active=$(systemctl --user is-active "$timer" 2>/dev/null || true)
    enabled=$(systemctl --user is-enabled "$timer" 2>/dev/null || true)
    if [[ $active != inactive || $enabled != disabled ]]; then
      rollback_failed=true
    fi
  done
  if [[ $rollback_failed == true ]]; then
    add_host_fail timer_rollback_failed \
      'restic timer rollback was incomplete; disable and stop all three restic timers before retrying'
    return 1
  fi
}

add_host_enable_timers() {
  local timer state
  if ! systemctl --user enable --now \
    restic-backup.timer restic-maintenance.timer restic-check.timer; then
    add_host_rollback_timers || return 1
    add_host_fail timer_activation_failed 'could not enable restic timers; attempted to disable all three'
    return 1
  fi
  for timer in restic-backup.timer restic-maintenance.timer restic-check.timer; do
    state=$(systemctl --user is-active "$timer" 2>/dev/null || true)
    if [[ $state != active ]]; then
      add_host_rollback_timers || return 1
      add_host_fail timer_activation_failed "restic timer is not active after enablement: $timer"
      return 1
    fi
    state=$(systemctl --user is-enabled "$timer" 2>/dev/null || true)
    if [[ $state != enabled ]]; then
      add_host_rollback_timers || return 1
      add_host_fail timer_activation_failed "restic timer is not enabled after enablement: $timer"
      return 1
    fi
  done
}

add_host_run_restic() {
  local error_type=$1 success_message=$2 display_output=$3 output
  shift 3
  output=$(mktemp)
  add_host_temp_files+=("$output")
  if ! "$@" >"$output" 2>&1; then
    add_host_error_type=$error_type
    printf 'Restic %s failed; rerun the corresponding restic-home command for details.\n' \
      "$add_host_phase" >&2
    return 1
  fi
  if [[ $display_output == true ]]; then
    command cat -- "$output"
  fi
  rm -f -- "$output"
  printf '%s\n' "$success_message"
}

restic_home_add_host() {
  local command_name live_host has_secrets source_dir source_file existing enabled
  local backup_calendar maintenance_calendar check_calendar restic_home
  local expected_file restore_dir restored_file

  [[ $(uname -s) == Linux ]] || add_host_fail unsupported_platform 'restic-home add-host is supported only on Linux'
  [[ -t 0 && -t 1 ]] || add_host_fail tty_required 'restic-home add-host requires an interactive terminal'
  for command_name in chezmoi gum taplo systemd-analyze systemctl cmp flock mktemp; do
    add_host_require_command "$command_name"
  done

  live_host=$(add_host_template_value '[[ .chezmoi.hostname ]]')
  [[ $live_host == "$host" ]] ||
    add_host_fail hostname_mismatch "rendered host $host does not match current chezmoi hostname $live_host"
  [[ $host =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] ||
    add_host_fail hostname_invalid "unsupported hostname for a repository ID: $host"
  has_secrets=$(add_host_template_value '[[ if has "secrets" .roles ]]true[[ else ]]false[[ end ]]')
  [[ $has_secrets == true ]] || add_host_fail role_missing 'the secrets role is required for restic-home add-host'

  source_dir=$(chezmoi source-path)
  source_file="$source_dir/.chezmoidata/restic.toml"
  [[ -f $source_file && ! -L $source_file ]] ||
    add_host_fail source_invalid "restic source configuration is not a regular file: $source_file"

  printf 'Current Restic home backup host: %s\n' "$host"
  add_host_confirm "Configure Restic home backup for $host?"

  existing=$(add_host_template_value '[[ if hasKey .restic.hosts .chezmoi.hostname ]]true[[ else ]]false[[ end ]]')
  if [[ $existing == true ]]; then
    enabled=$(add_host_template_value '[[ (index .restic.hosts .chezmoi.hostname).enabled ]]')
    [[ $enabled == true ]] || add_host_fail host_disabled "restic host entry is disabled: $host"
    printf 'Enabled Restic host entry already exists; resuming onboarding.\n'
  else
    add_host_prompt_calendar 'Backup calendar' "$add_host_default_backup_calendar"
    backup_calendar=$add_host_prompted_calendar
    add_host_prompt_calendar 'Maintenance calendar' "$add_host_default_maintenance_calendar"
    maintenance_calendar=$add_host_prompted_calendar
    add_host_prompt_calendar 'Check calendar' "$add_host_default_check_calendar"
    check_calendar=$add_host_prompted_calendar
    printf 'Backup: %s\nMaintenance: %s\nCheck: %s\n' \
      "$backup_calendar" "$maintenance_calendar" "$check_calendar"
    add_host_confirm 'Add this host to restic.toml?'
    add_host_set_phase source_update source_update_failed
    add_host_append_source "$source_file" "$backup_calendar" "$maintenance_calendar" "$check_calendar"
  fi

  add_host_set_phase apply apply_failed
  add_host_apply_targets
  systemctl --user daemon-reload
  add_host_verify_services_inactive
  add_host_timer_state
  if [[ $add_host_timers_already_active == true ]]; then
    printf 'Restic home backup is already configured and all timers are active.\n'
    printf 'Source configuration: %s\nNo commit or push was performed.\n' "$source_file"
    return 0
  fi
  restic_home="$HOME/.local/bin/restic-home"
  add_host_set_phase repository repository_unavailable
  if "$restic_home" snapshots --json >/dev/null 2>&1; then
    add_host_run_restic repository_unavailable 'Existing repository is readable.' true \
      "$restic_home" snapshots --compact
    add_host_confirm 'Use this existing Restic repository?'
  else
    add_host_confirm 'No readable repository was found. Initialize it?'
    add_host_run_restic repository_unavailable 'Repository initialized.' false \
      "$restic_home" init --quiet
  fi

  restore_dir=$(mktemp -d)
  add_host_temp_dirs+=("$restore_dir")
  expected_file="$restore_dir/expected-excludes"
  cp -- "$HOME/.config/restic/excludes" "$expected_file"

  add_host_set_phase backup backup_failed
  add_host_run_restic backup_failed 'Initial backup completed.' false "$restic_home" backup
  add_host_set_phase check check_failed
  add_host_run_restic check_failed 'Repository check completed.' false "$restic_home" check
  add_host_set_phase restore restore_failed
  add_host_run_restic restore_failed 'Representative file restored.' false \
    "$restic_home" restore latest --target "$restore_dir/restored" \
      --include "$HOME/.config/restic/excludes"
  restored_file="$restore_dir/restored/${HOME#/}/.config/restic/excludes"
  [[ -f $restored_file ]] || add_host_fail restore_failed 'representative restore did not create the Restic exclude file'
  cmp -s -- "$expected_file" "$restored_file" ||
    add_host_fail restore_failed 'representative restore does not match the Restic exclude file'
  printf 'Representative restore verified.\n'

  add_host_set_phase cleanup cleanup_failed
  add_host_cleanup ||
    add_host_fail cleanup_failed 'temporary Restic output or restored content could not be removed; timers remain disabled'

  add_host_set_phase timers timer_activation_failed
  add_host_enable_timers
  add_host_phase=complete
  add_host_error_type=""
  printf 'Restic home onboarding completed for %s.\n' "$host"
  printf 'Source configuration: %s\nNo commit or push was performed.\n' "$source_file"
}

restic_home_add_host_command() (
  add_host_initialize_recording
  trap add_host_finish EXIT
  trap add_host_cancel INT TERM
  add_host_set_phase preflight precondition_failed
  restic_home_add_host
)
