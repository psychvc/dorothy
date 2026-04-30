#!/usr/bin/env zsh

function _safe_source() {
    [[ -r "$1" ]] && [[ -f "$1" ]] && source "$1" 
  }

      
  function __eval_wrap {
                # trim -- prefix
                if [[ ${1-} == '--' ]]; then
                        shift
                fi
                # proceed
                printf '%s\n' "$*"
                "$@" # eval
   }
         
_safe_source '$DOROTHY/user/source/theme'

DOROTHY_THEME_OVERRIDE='$theme'

_safe_source '$DOROTHY/init.sh'
