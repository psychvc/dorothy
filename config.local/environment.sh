#!/usr/bin/env zsh
# shellcheck disable=SC1072,SC1073,SC1083,SC2034
# place all export declarations (e.g. export VAR) before their definitions/assignments (VAR=...), otherwise no bash v3 compatibility

function _safe_source() {
  [[ -r "$1" ]] && [[ -f "$1" ]] && source "$1"
}

_safe_source "$DOROTHY/config/environment.sh"

CACHE_LOCK_FILE=''
CACHE_RESULT_FILE=''
function __cache {
        # cache the environment setup commands
        local cache_dir="$DOROTHY/state/setup-environment-commands"
        if [[ $option_invalidate == 'yes' ]]; then
                __dump --debug --value='== CACHE INVALIDATED ==' {cache_dir} || return $?
                rm -rf "$cache_dir" || :
        fi
        local option_validity_seconds='' option_checksum_command=()
        while [[ $# -ne 0 ]]; do
                item="$1"
                shift
                case "$item" in
                '--validity-seconds='*) option_validity_seconds="${item#*=}" ;;
                '--')
                        option_checksum_command+=("$@")
                        shift "$#"
                        break
                        ;;
                *)
                        __print_lines "ERROR: Unrecognised __cache argument: $item" >&2
                        return 22 # EINVAL 22 Invalid argument
                        ;;
                esac
        done

if [[ -z $option_validity_seconds ]]; then
		# default to thirty minutes
		option_validity_seconds=1800 # 600
	fi
	if [[ ${#option_checksum_command[@]} -eq 0 ]]; then
		option_checksum_command+=(openssl dgst -md5 -r)
	fi
	if __command_missing -- "${option_checksum_command[0]}"; then
		__print_lines "ERROR: To use __cache you must specify a checksum command that exists and is executable, unlike: ${option_checksum_command[0]}" >&2
		return 22 # EINVAL 22 Invalid argument
	fi
	# @todo instead of ignore_env_vars change it to list of only vars instead, which is automatically updated from what this actually sets
	local checksum context_id
	checksum="$("${option_checksum_command[@]}" <<<"$INITIAL_EXPORTED_VARIABLE_COMPOSITE" | __cut)" || return $?
	context_id="setup-environment-commands.$option_shell.$checksum"
	# get an exclusive lock on the context
	CACHE_LOCK_FILE="$(__get_semlock "$context_id")" || return $?
	# get the result cache of the context
	CACHE_RESULT_FILE="$cache_dir/$context_id"
	# if cache is available and applicable
	if [[ -f $CACHE_RESULT_FILE ]]; then
		local now_seconds cache_seconds cache_ago_seconds
		# if cache is still valid
		# local now_seconds cache_seconds cache_ago_seconds
		now_seconds="$(__get_epoch_seconds)" || return $?
		cache_seconds="$(date -r "$CACHE_RESULT_FILE" +%s)" || return $?
		cache_ago_seconds="$((now_seconds - cache_seconds))"
		if [[ $cache_ago_seconds -lt $option_validity_seconds ]]; then
			# then use the cache
			__dump "$debug_or_stderr_arg" --value='== CACHE HIT ==' {CACHE_RESULT_FILE} {INITIAL_EXPORTED_VARIABLE_COMPOSITE} || return $?
			cat -- "$CACHE_RESULT_FILE" || return $?
			rm -f -- "$CACHE_LOCK_FILE" || return $?
			trap - EXIT # disable the `env.bash` trap
			exit 0      # must be exit, otherwise `setup-environment-commands` will continue
		else
			__dump "$debug_or_stderr_arg" --value='== CACHE EXPIRED ==' {CACHE_RESULT_FILE} {INITIAL_EXPORTED_VARIABLE_COMPOSITE} || return $?
		fi
	else
		__dump "$debug_or_stderr_arg" --value='== CACHE 404 ==' {CACHE_RESULT_FILE} {INITIAL_EXPORTED_VARIABLE_COMPOSITE} || return $?
		__mkdirp "$cache_dir" || return $?
	fi
	# cache needs updating
	function __on_env_finish__cache {
		local -i status=$?
		trap - EXIT # disable our cache trap override
		if [[ $status -ne 0 ]]; then
			rm -f -- "$CACHE_LOCK_FILE"
			return "$status"
		fi
		# store the result
		__dump --debug --value='== CACHE UPDATING ==' {CACHE_RESULT_FILE} || return $?
		__on_env_finish | tee -- "$CACHE_RESULT_FILE" || __return $? -- rm -f -- "$CACHE_LOCK_FILE" || return $?
		rm -f -- "$CACHE_LOCK_FILE" || return $?
		return 0
	}
	trap __on_env_finish__cache EXIT # replace our prior trap with one that caches the result
}

# support caching the environment
__cache -- /opt/homebrew/bin/xxhsum -H3 || :
#__cache || :

# dorothy
export HOMEBREW_RUBY_VERSION
HOMEBREW_RUBY_VERSION='default'

# https://doc.rust-lang.org/cargo/reference/config.html#netgit-fetch-with-cli
export CARGO_NET_GIT_FETCH_WITH_CLI
CARGO_NET_GIT_FETCH_WITH_CLI='true'
