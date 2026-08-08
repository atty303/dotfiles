#!/bin/bash

set -euo pipefail

runner_directory=$1
staging_directory=$2
recipient=$3
log_directory=$4

if [[ -x "$HOME/.local/bin/mise" ]]; then
  mise=$HOME/.local/bin/mise
elif mise=$(command -v mise); then
  :
else
  echo "mise is not installed on the Mac host" >&2
  exit 1
fi

export CHEZMOI_E2E_LOG_DIRECTORY=$log_directory

cd "$runner_directory"
"$mise" trust
"$mise" install
"$mise" exec -- deno run -A tests/e2e/main.ts mac host "$staging_directory" "$recipient"
