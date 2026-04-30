#!/usr/bin/env zsh
#shellcheck disable=SC1071

  function _safe_source() {
    [[ -r "$1" ]] && [[ -f "$1" ]] && source "$1"
  }
   
  function __eval_wrap() {
		# trim -- prefix
		if [[ ${1-} == '--' ]]; then
			shift
		fi
		# proceed
		printf '%s\n' "$*"
		"$@" # eval
  }


  function __repl_zsh() { 
   DOROTHY="$HOME/.local/share/dorothy"
   PATH="$DOROTHY/commands:$PATH"
  _safe_source "$DOROTHY/user/sources/zsh.zsh"
  
  setup-util-zsh --quiet  || return $?
  _safe_source "$DOROTHY/user/init.zsh" || return $?

  function __get_themes {
     fs-path --no-parents --no-extensions -- "$DOROTHY/themes/"*.* "$DOROTHY/user/themes/"*.* | echo-unique --stdin || return $?
   }

  local  item='' DOROTHY_THEME=('oz')
  source "$DOROTHY/sources/config.sh"
  export DOROTHY_THEME='oz'
  load_dorothy_config 'interactive.sh'
   __get_themes
  theme="$(choose --linger --required --default="$DOROTHY_THEME"  --question='Which theme to use?' '$DOROTHY_THEME')"
 }
 
__repl_zsh "$@"
