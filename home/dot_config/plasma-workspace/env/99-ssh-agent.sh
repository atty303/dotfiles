#!/bin/sh
set -eu

# (A) SSH_AUTH_SOCK が「実在するUNIXソケット」なら、それを最優先（= agent forward を守る）
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
  exit 0
fi

# (B) KDEが入れた固定値など、実体がない/壊れてる場合
unset SSH_AUTH_SOCK
