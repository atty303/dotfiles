#!/usr/bin/env bash
set -e

NU_VERSION=0.102.0
NU_LIBC=gnu
NU_URL="https://github.com/nushell/nushell/releases/download/${NU_VERSION}/nu-${NU_VERSION}-$(uname -m)-unknown-linux-${NU_LIBC}.tar.gz"

mkdir -p ~/.local/bin
if [ ! -f ~/.local/bin/nu ]; then
  curl -L "$NU_URL" -o /tmp/nu.tar.gz
  tar -xzf /tmp/nu.tar.gz -C /tmp
  mv /tmp/nu* ~/.local/bin
  chmod +x ~/.local/bin/nu*
fi
