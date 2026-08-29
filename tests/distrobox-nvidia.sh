#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

chezmoi_bin="$(command -v chezmoi)"
mkdir -p "$temporary/missing" "$temporary/success" "$temporary/failure"

cat >"$temporary/missing/nvidia-smi" <<'EOF'
#!/bin/sh
exit 127
EOF
cat >"$temporary/success/nvidia-smi" <<'EOF'
#!/bin/sh
test "${1-}" = -L
EOF
cat >"$temporary/failure/nvidia-smi" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$temporary/missing/nvidia-smi" "$temporary/success/nvidia-smi" \
  "$temporary/failure/nvidia-smi"

render_manifest() {
  local path_dir="${1:?PATH directory is required}"
  local source="${2:?manifest source is required}"
  local destination="${3:?render destination is required}"

  PATH="$path_dir:$PATH" "$chezmoi_bin" execute-template --source "$repository" \
    <"$source" >"$destination"
}

for mode in missing failure success; do
  render_manifest "$temporary/$mode" \
    "$repository/home/dot_config/distrobox/assemble/noctalia.ini.tmpl" \
    "$temporary/noctalia-$mode.ini"
  render_manifest "$temporary/$mode" \
    "$repository/home/dot_config/distrobox/assemble/scroll.ini.tmpl" \
    "$temporary/scroll-$mode.ini"
done

for manifest in "$temporary/noctalia-missing.ini" "$temporary/noctalia-failure.ini" \
  "$temporary/scroll-missing.ini" "$temporary/scroll-failure.ini"; do
  if grep -Fqx 'nvidia=true' "$manifest"; then
    printf 'NVIDIA integration was enabled without a working nvidia-smi: %s\n' "$manifest" >&2
    exit 1
  fi
done

for manifest in "$temporary/noctalia-success.ini" "$temporary/scroll-success.ini"; do
  grep -Fqx 'nvidia=true' "$manifest"
done

grep -Fxq '[noctalia]' "$temporary/noctalia-success.ini"
grep -Fxq '[scroll]' "$temporary/scroll-success.ini"
if grep -Eq '^\[(noctalia|scroll)-nvidia\]$' "$temporary"/*.ini; then
  printf 'NVIDIA rendering changed a managed container name\n' >&2
  exit 1
fi

[[ "$(sha256sum <"$temporary/noctalia-missing.ini")" != \
  "$(sha256sum <"$temporary/noctalia-success.ini")" ]]
[[ "$(sha256sum <"$temporary/scroll-missing.ini")" != \
  "$(sha256sum <"$temporary/scroll-success.ini")" ]]

if command -v distrobox >/dev/null 2>&1; then
  normal_dry_run="$(distrobox assemble create --dry-run \
    --file "$temporary/noctalia-missing.ini" --name noctalia 2>/dev/null)"
  nvidia_dry_run="$(distrobox assemble create --dry-run \
    --file "$temporary/noctalia-success.ini" --name noctalia 2>/dev/null)"
  grep -Fq -- '--name "noctalia"' <<<"$normal_dry_run"
  grep -Fq -- '--name "noctalia"' <<<"$nvidia_dry_run"
  if grep -Fq -- '--nvidia "1"' <<<"$normal_dry_run"; then
    printf 'normal Distrobox dry run enabled NVIDIA integration\n' >&2
    exit 1
  fi
  grep -Fq -- '--nvidia "1"' <<<"$nvidia_dry_run"
fi

printf 'Distrobox NVIDIA rendering tests passed\n'
