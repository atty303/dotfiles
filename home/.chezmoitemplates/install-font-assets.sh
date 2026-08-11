# shellcheck shell=sh

fonts_dir=${fonts_dir:?fonts_dir is required}

download_font_asset() {
  destination=${1:?destination is required}
  url=${2:?URL is required}

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 --retry-delay 1 -o "$destination" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$destination" "$url"
  else
    echo "font installer: curl or wget is required" >&2
    return 1
  fi
}

font_families_satisfied() {
  mode=${1:?family match mode is required}
  families=${2:?font families are required}
  matched=false
  old_ifs=$IFS
  IFS='|'

  for family in $families; do
    if font_family_installed "$family"; then
      if [ "$mode" = any ]; then
        IFS=$old_ifs
        return 0
      fi
      matched=true
    elif [ "$mode" = all ]; then
      IFS=$old_ifs
      return 1
    fi
  done

  IFS=$old_ifs
  [ "$mode" = all ] && [ "$matched" = true ]
}

install_font_asset() (
  id=${1:?asset ID is required}
  family_mode=${2:?family match mode is required}
  families=${3:?font families are required}
  url=${4:?URL is required}
  expected_sha256=${5:?SHA-256 is required}
  kind=${6:?asset kind is required}
  files=${7:?font files are required}

  if font_families_satisfied "$family_mode" "$families"; then
    echo "Font asset already satisfied: $id"
    exit 0
  fi

  tmpdir=$(mktemp -d) || exit 1
  trap 'rm -rf "$tmpdir"' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  payload=$tmpdir/payload
  download_font_asset "$payload" "$url"
  actual_sha256=$(font_file_sha256 "$payload")
  if [ "$actual_sha256" != "$expected_sha256" ]; then
    echo "font installer: SHA-256 mismatch for $id" >&2
    exit 1
  fi

  case "$kind" in
    file)
      install -m 0644 "$payload" "$fonts_dir/$files"
      ;;
    zip)
      extracted=$tmpdir/extracted
      mkdir -p "$extracted"
      extract_font_archive "$payload" "$extracted"

      old_ifs=$IFS
      IFS='|'
      for relative_path in $files; do
        source_path=$(find "$extracted" -type f -path "*/$relative_path" -print -quit)
        if [ -z "$source_path" ]; then
          echo "font installer: $relative_path was not found in $id" >&2
          exit 1
        fi
        install -m 0644 "$source_path" "$fonts_dir/$(basename "$relative_path")"
      done
      IFS=$old_ifs
      ;;
    *)
      echo "font installer: unsupported asset kind '$kind' for $id" >&2
      exit 1
      ;;
  esac

  echo "Installed font asset: $id"
)
