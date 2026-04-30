#!/usr/bin/env sh
# shellcheck disable=SC1091,SC2086

function _safe_source() {
  [[ -f "$1" ]] && source "$1"
}

_safe_source "$DOROTHY/user/sources/mytest.bash"

_safe_source "$HOME/.shrc"
