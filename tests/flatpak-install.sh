#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

fake_bin="$temporary/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/flatpak" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'flatpak' >>"$FAKE_LOG"
printf ' %q' "$@" >>"$FAKE_LOG"
printf '\n' >>"$FAKE_LOG"

case "${1:-}" in
  remotes)
    if [[ "${FAKE_FAIL_QUERY:-}" == remotes ]]; then
      exit 71
    fi
    cat "$FAKE_REMOTES"
    ;;
  remote-add)
    name="${4:?remote name is required}"
    printf '%s\n' "$name" >>"$FAKE_REMOTES"
    ;;
  list)
    if [[ "${FAKE_FAIL_QUERY:-}" == list ]]; then
      exit 71
    fi
    while IFS= read -r ref; do
      [[ -n "$ref" ]] || continue
      printf '%s\t%s\n' "${ref%//*}" "${ref##*//}"
    done <"$FAKE_APPS"
    ;;
  install)
    ref="${6:?ref is required}"
    if [[ "${FAKE_FAIL_REF:-}" == "$ref" ]]; then
      exit 42
    fi
    printf '%s\n' "$ref" >>"$FAKE_APPS"
    ;;
  *)
    printf 'unexpected flatpak command: %q ' "$@" >&2
    printf '\n' >&2
    exit 2
    ;;
esac
EOF
chmod +x "$fake_bin/flatpak"

cat >"$fake_bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'sudo' >>"$FAKE_LOG"
printf ' %q' "$@" >>"$FAKE_LOG"
printf '\n' >>"$FAKE_LOG"
exec "$@"
EOF
chmod +x "$fake_bin/sudo"

rendered="$temporary/flatpak.sh"
chezmoi execute-template \
  --source "$repository" \
  <"$repository/home/.chezmoiscripts/linux/run_after_flatpak.sh.tmpl" \
  >"$rendered"
chmod +x "$rendered"
bash -n "$rendered"

run_script() {
  FAKE_LOG="$1" \
    FAKE_REMOTES="$2" \
    FAKE_APPS="$3" \
    PATH="$fake_bin:$PATH" \
    "$rendered"
}

remotes="$temporary/remotes"
apps="$temporary/apps"
log="$temporary/commands.log"
printf 'flathub\n' >"$remotes"
: >"$apps"
: >"$log"
run_script "$log" "$remotes" "$apps"

[[ "$(wc -l <"$apps")" -eq 26 ]]
grep -Fxq 'GeForceNOW' "$remotes"
grep -Fq 'sudo flatpak remote-add --system --if-not-exists GeForceNOW https://international.download.nvidia.com/GFNLinux/flatpak/geforcenow.flatpakrepo' "$log"
grep -Fq 'sudo flatpak install --system --assumeyes --noninteractive GeForceNOW com.nvidia.geforcenow//master' "$log"
grep -Fq 'sudo flatpak install --system --assumeyes --noninteractive flathub org.winehq.Wine//stable-25.08' "$log"
if grep -Eq -- '--user|uninstall|remote-delete' "$log"; then
  printf 'lifecycle script attempted a user or removal operation\n' >&2
  exit 1
fi

: >"$log"
run_script "$log" "$remotes" "$apps"
if grep -Eq 'remote-add|install' "$log"; then
  printf 'idempotent run attempted to add or install something\n' >&2
  exit 1
fi

failed_apps="$temporary/failed-apps"
failed_log="$temporary/failed.log"
: >"$failed_apps"
: >"$failed_log"
set +e
FAKE_FAIL_REF='com.discordapp.Discord//stable' \
  run_script "$failed_log" "$remotes" "$failed_apps"
status=$?
set -e
[[ "$status" -eq 42 ]]
if grep -Eq -- '--user|uninstall|remote-delete' "$failed_log"; then
  printf 'failed run attempted a user or removal operation\n' >&2
  exit 1
fi

for query in remotes list; do
  query_log="$temporary/query-${query}.log"
  : >"$query_log"
  set +e
  FAKE_FAIL_QUERY="$query" run_script "$query_log" "$remotes" "$apps"
  status=$?
  set -e
  [[ "$status" -eq 1 ]]
  if grep -Fq 'sudo ' "$query_log"; then
    printf 'query failure unexpectedly attempted a privileged mutation: %s\n' "$query" >&2
    exit 1
  fi
done

printf 'Flatpak installation tests passed\n'
