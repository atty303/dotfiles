require_private_file() {
  local path=$1
  local mode

  if [[ ! -f $path || -L $path ]]; then
    printf 'missing regular restic configuration: %s\n' "$path" >&2
    return 1
  fi
  mode=$(stat -c '%a' "$path")
  if [[ $mode != 600 && $mode != 400 ]]; then
    printf 'restic configuration must have mode 600 or 400: %s has %s\n' \
      "$path" "$mode" >&2
    return 1
  fi
}

load_restic_configuration() {
  local requested_repository_id=$1
  local line key value
  local access_key_seen=false
  local secret_key_seen=false
  local repository_base_seen=false
  local password_seen=false
  local access_key=
  local secret_key=
  local repository_base=
  local password=

  require_private_file "$configuration_file" || return 1

  while IFS= read -r line || [[ -n $line ]]; do
    [[ -z $line || $line == \#* ]] && continue
    if [[ $line != *=* ]]; then
      printf 'invalid restic configuration line in %s\n' "$configuration_file" >&2
      return 1
    fi
    key=${line%%=*}
    value=${line#*=}
    if [[ -z $value ]]; then
      printf 'empty restic configuration field: %s\n' "$key" >&2
      return 1
    fi
    case $key in
      AWS_ACCESS_KEY_ID)
        [[ $access_key_seen == false ]] || {
          printf 'duplicate restic configuration field: %s\n' "$key" >&2
          return 1
        }
        access_key_seen=true
        access_key=$value
        ;;
      AWS_SECRET_ACCESS_KEY)
        [[ $secret_key_seen == false ]] || {
          printf 'duplicate restic configuration field: %s\n' "$key" >&2
          return 1
        }
        secret_key_seen=true
        secret_key=$value
        ;;
      RESTIC_REPOSITORY_BASE)
        [[ $repository_base_seen == false ]] || {
          printf 'duplicate restic configuration field: %s\n' "$key" >&2
          return 1
        }
        repository_base_seen=true
        repository_base=$value
        ;;
      RESTIC_PASSWORD)
        [[ $password_seen == false ]] || {
          printf 'duplicate restic configuration field: %s\n' "$key" >&2
          return 1
        }
        password_seen=true
        password=$value
        ;;
      *)
        printf 'unsupported restic configuration field: %s\n' "$key" >&2
        return 1
        ;;
    esac
  done <"$configuration_file"

  if [[ $access_key_seen != true || $secret_key_seen != true || \
    $repository_base_seen != true || $password_seen != true ]]; then
    printf '%s\n' \
      'restic configuration must define AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, RESTIC_REPOSITORY_BASE, and RESTIC_PASSWORD' >&2
    return 1
  fi

  export AWS_ACCESS_KEY_ID="$access_key"
  export AWS_SECRET_ACCESS_KEY="$secret_key"
  unset RESTIC_PASSWORD_COMMAND RESTIC_PASSWORD_FILE RESTIC_REPOSITORY_FILE
  export RESTIC_REPOSITORY="${repository_base%/}/$requested_repository_id"
  export RESTIC_PASSWORD="$password"
}
