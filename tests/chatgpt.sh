#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

test_home="$temporary/home"
fake_bin="$temporary/bin"
fixture="$temporary/repo"
mkdir -p "$test_home/.local/bin" "$test_home/.local/libexec" \
  "$test_home/.local/share/chatgpt" "$fake_bin" "$fixture/repodata"

chezmoi cat --source "$repository" --override-data '{"roles":["desktop"],"chezmoi":{"osRelease":{"id":"bazzite","idLike":"fedora"}}}' \
  ~/.local/bin/chatgpt >"$test_home/.local/bin/chatgpt"
chezmoi cat --source "$repository" --override-data '{"roles":["desktop"],"chezmoi":{"osRelease":{"id":"bazzite","idLike":"fedora"}}}' \
  ~/.local/libexec/chatgpt-update >"$test_home/.local/libexec/chatgpt-update"
chezmoi cat --source "$repository" --override-data '{"roles":["desktop"],"chezmoi":{"osRelease":{"id":"bazzite","idLike":"fedora"}}}' \
  ~/.local/share/chatgpt/codex-linux-repository.asc \
  >"$test_home/.local/share/chatgpt/codex-linux-repository.asc"
chmod +x "$test_home/.local/bin/chatgpt" "$test_home/.local/libexec/chatgpt-update"
bash -n "$test_home/.local/bin/chatgpt"
bash -n "$test_home/.local/libexec/chatgpt-update"

printf 'rpm payload\n' >"$fixture/chatgpt-test.rpm"
rpm_sha=$(sha256sum "$fixture/chatgpt-test.rpm" | awk '{print $1}')
cat >"$fixture/primary.xml" <<EOF
<metadata packages="1">
<package type="rpm">
<name>chatgpt</name><arch>x86_64</arch>
<version epoch="0" ver="99.1" rel="1"/>
<checksum type="sha256" pkgid="YES">$rpm_sha</checksum>
<location href="chatgpt-test.rpm"/>
</package>
</metadata>
EOF
gzip -c "$fixture/primary.xml" >"$fixture/repodata/primary.xml.gz"
primary_sha=$(sha256sum "$fixture/repodata/primary.xml.gz" | awk '{print $1}')
cat >"$fixture/repodata/repomd.xml" <<EOF
<repomd><data type="primary">
<checksum type="sha256">$primary_sha</checksum>
<location href="repodata/primary.xml.gz"/>
</data></repomd>
EOF
printf 'signature\n' >"$fixture/repodata/repomd.xml.asc"

cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
url=""
while (($#)); do
  case "$1" in
    --output) output=$2; shift 2 ;;
    http*) url=$1; shift ;;
    *) shift ;;
  esac
done
relative=${url#https://persistent.oaistatic.com/codex-app-prod/linux/rpm/x86_64/}
[[ ${FAKE_CURL_FAIL:-false} != true ]] || exit 22
cp "$FAKE_REPO/$relative" "$output"
printf '%s\n' "$relative" >>"$FAKE_CURL_LOG"
EOF

cat >"$fake_bin/gpg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $* == *--with-colons* ]]; then
  if [[ ${FAKE_BAD_FINGERPRINT:-false} == true ]]; then
    printf 'fpr:::::::::0000000000000000000000000000000000000000:\n'
  else
    printf 'fpr:::::::::3BFA0E4AE8B8CC16A2D9BA684A3B4A566C4660E4:\n'
  fi
fi
EOF

cat >"$fake_bin/rpmkeys" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $* == *--checksig* ]]; then
  printf '%s: digests signatures OK\n' "${*: -1}"
fi
EOF

cat >"$fake_bin/rpm2cpio" <<'EOF'
#!/usr/bin/env bash
printf 'payload\n'
EOF

cat >"$fake_bin/cpio" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p usr/lib/chatgpt/resources usr/share/pixmaps
cat >usr/lib/chatgpt/ChatGPT <<'APP'
#!/usr/bin/env bash
printf '%s\n' "${CODEX_SPARKLE_ENABLED:-unset}" >"$FAKE_APP_LOG"
printf '%s\n' "$@" >>"$FAKE_APP_LOG"
APP
chmod +x usr/lib/chatgpt/ChatGPT
printf '{"version":"99.1"}\n' >usr/lib/chatgpt/resources/linux-package-metadata.json
printf 'icon\n' >usr/share/pixmaps/chatgpt.png
EOF
chmod +x "$fake_bin"/*

run_chatgpt() {
  HOME="$test_home" XDG_STATE_HOME="$test_home/.local/state" PATH="$fake_bin:/usr/bin:/bin" \
    FAKE_REPO="$fixture" FAKE_CURL_LOG="$temporary/curl.log" \
    FAKE_APP_LOG="$temporary/app.log" \
    "$test_home/.local/bin/chatgpt" "$@"
}

: >"$temporary/curl.log"
mkdir -p "$test_home/.local/opt/chatgpt"
ln -s versions/interrupted "$test_home/.local/opt/chatgpt/.current.new"
run_chatgpt --update
[[ -x "$test_home/.local/opt/chatgpt/current/usr/lib/chatgpt/ChatGPT" ]]
[[ $(readlink "$test_home/.local/opt/chatgpt/current") == versions/99.1-1 ]]
[[ ! -e "$test_home/.local/opt/chatgpt/.current.new" ]]
[[ $(find "$test_home/.local/opt/chatgpt/versions" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ]]

run_chatgpt project-one
[[ $(sed -n '1p' "$temporary/app.log") == false ]]
[[ $(sed -n '2p' "$temporary/app.log") == project-one ]]
requests=$(wc -l <"$temporary/curl.log")
run_chatgpt project-two
[[ $(wc -l <"$temporary/curl.log") -eq $requests ]]

printf '0 success\n' >"$test_home/.local/state/chatgpt/last-check"
FAKE_CURL_FAIL=true run_chatgpt fallback
[[ $(sed -n '2p' "$temporary/app.log") == fallback ]]
printf '0 success\n' >"$test_home/.local/state/chatgpt/last-check"
if FAKE_BAD_FINGERPRINT=true run_chatgpt --update >/dev/null 2>&1; then
  printf 'ChatGPT updater accepted an unexpected signing key\n' >&2
  exit 1
fi
[[ $(readlink "$test_home/.local/opt/chatgpt/current") == versions/99.1-1 ]]

desktop="$temporary/chatgpt.desktop"
chezmoi cat --source "$repository" --override-data '{"roles":["desktop"],"chezmoi":{"osRelease":{"id":"bazzite","idLike":"fedora"}}}' \
  ~/.local/share/applications/chatgpt.desktop >"$desktop"
desktop-file-validate "$desktop"
grep -Fxq 'MimeType=x-scheme-handler/codex;' "$desktop"
if grep -Eq 'text/csv|officedocument|ms-excel|tab-separated' "$desktop"; then
  printf 'ChatGPT desktop entry registered document MIME types\n' >&2
  exit 1
fi

printf 'ChatGPT portable installation tests passed\n'
