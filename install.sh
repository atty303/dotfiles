#!/bin/sh

set -eu

prompt_roles=false
if [ "${1-}" = "--prompt-roles" ]; then
  prompt_roles=true
  shift
fi

if ! chezmoi="$(command -v chezmoi)"; then
  bin_dir="${HOME}/.local/bin"
  chezmoi="${bin_dir}/chezmoi"
  echo "Installing chezmoi to '${chezmoi}'" >&2
  if command -v curl >/dev/null; then
    chezmoi_install_script="$(curl -fsSL https://get.chezmoi.io)"
  elif command -v wget >/dev/null; then
    chezmoi_install_script="$(wget -qO- https://get.chezmoi.io)"
  else
    echo "To install chezmoi, you must have curl or wget installed." >&2
    exit 1
  fi
  sh -c "${chezmoi_install_script}" -- -b "${bin_dir}"
  unset chezmoi_install_script bin_dir
fi

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
roles=development
case "$(uname -s)" in
  Darwin) roles=development,desktop ;;
  Linux)
    if find /usr/share/wayland-sessions /usr/share/xsessions -maxdepth 1 -type f -name '*.desktop' -print -quit 2>/dev/null | grep -q .; then
      roles=development,desktop
    fi
    ;;
esac

if [ "$prompt_roles" = true ]; then
  printf 'Roles (development,desktop,gaming,work) [%s]: ' "$roles" >&2
  IFS= read -r selected_roles
  if [ "$selected_roles" = "-" ]; then
    roles=
  elif [ -n "$selected_roles" ]; then
    roles=$selected_roles
  fi
fi

# exec: replace current process with chezmoi init
exec "$chezmoi" init --apply --verbose --no-tty \
  --promptString "Roles=$roles" \
  "--source=$script_dir" "$@"
