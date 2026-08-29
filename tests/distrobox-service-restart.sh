#!/usr/bin/env bash

set -euo pipefail

repository="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

fake_bin="$temporary/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$FAKE_LOG"
if [[ "$*" == "--user is-active --quiet test-shell.service" ]]; then
  exit "$FAKE_SERVICE_STATUS"
fi
if [[ "$*" == "--user restart test-shell.service" ]]; then
  exit "$FAKE_RESTART_STATUS"
fi
EOF

cat >"$fake_bin/distrobox" <<'EOF'
#!/usr/bin/env bash
printf 'distrobox %s\n' "$*" >>"$FAKE_LOG"
EOF

cat >"$fake_bin/scroll-helper" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "$fake_bin/systemctl" "$fake_bin/distrobox" "$fake_bin/scroll-helper"

rendered="$temporary/distrobox.sh"
chezmoi --source "$repository" execute-template \
  --override-data '{"roles":["desktop"],"distrobox":{"roles":{"desktop":{"entries":[{"manifest":"dms.ini","name":"shell","service":"test-shell.service"}]}}}}' \
  <"$repository/home/.chezmoiscripts/linux/run_after_distrobox.sh.tmpl" \
  >"$rendered"
chmod +x "$rendered"
bash -n "$rendered"

run_case() {
  local name="${1:?name is required}"
  local service_status="${2:?service status is required}"
  local restart_status="${3:?restart status is required}"
  local expected_status="${4:?expected status is required}"
  local expect_applied="${5:?applied expectation is required}"
  local expected="${6:?expected log is required}"
  local expected_digest
  local case_dir="$temporary/$name"
  local log="$case_dir/commands.log"
  local status

  mkdir -p "$case_dir/home/.local/libexec" "$case_dir/state" "$case_dir/config/distrobox/assemble"
  : >"$case_dir/config/distrobox/assemble/dms.ini"
  cp "$fake_bin/scroll-helper" "$case_dir/home/.local/libexec/chezmoi-distrobox-scroll-update"
  set +e
  FAKE_LOG="$log" \
    FAKE_SERVICE_STATUS="$service_status" \
    FAKE_RESTART_STATUS="$restart_status" \
    HOME="$case_dir/home" \
    XDG_CONFIG_HOME="$case_dir/config" \
    XDG_STATE_HOME="$case_dir/state" \
    PATH="$fake_bin:$PATH" \
    "$rendered"
  status=$?
  set -e

  [[ "$status" == "$expected_status" ]]
  if [[ "$expect_applied" == yes ]]; then
    [[ -s "$case_dir/state/chezmoi/distrobox/shell.applied" ]]
    expected_digest="$(printf '%s\n' shell | sha256sum | cut -d ' ' -f 1)"
    [[ "$(<"$case_dir/state/chezmoi/distrobox/shell.applied")" == "$expected_digest" ]]
  else
    [[ ! -e "$case_dir/state/chezmoi/distrobox/shell.applied" ]]
  fi
  if [[ "$(<"$log")" != "$expected" ]]; then
    printf 'unexpected %s command log:\n%s\n' "$name" "$(<"$log")" >&2
    return 1
  fi
}

active_expected=$'systemctl --user daemon-reload\nsystemctl --user is-active --quiet test-shell.service\ndistrobox assemble create --replace --file '
active_expected+="$temporary/active/config/distrobox/assemble/dms.ini"
active_expected+=$' --name shell\nsystemctl --user reset-failed test-shell.service\nsystemctl --user restart test-shell.service'
run_case active 0 0 0 yes "$active_expected"

inactive_expected=$'systemctl --user daemon-reload\nsystemctl --user is-active --quiet test-shell.service\ndistrobox assemble create --replace --file '
inactive_expected+="$temporary/inactive/config/distrobox/assemble/dms.ini"
inactive_expected+=$' --name shell'
run_case inactive 3 0 0 yes "$inactive_expected"

restart_failed_expected=$'systemctl --user daemon-reload\nsystemctl --user is-active --quiet test-shell.service\ndistrobox assemble create --replace --file '
restart_failed_expected+="$temporary/restart-failed/config/distrobox/assemble/dms.ini"
restart_failed_expected+=$' --name shell\nsystemctl --user reset-failed test-shell.service\nsystemctl --user restart test-shell.service'
run_case restart-failed 0 23 23 no "$restart_failed_expected"

printf 'Distrobox managed service restart tests passed\n'
