#!/usr/bin/env zsh
# shellcheck disable=SC1071

PAUSE_RESTORE_TRACING_X=''
PAUSE_RESTORE_TRACING_V=''

function __pause_tracing {
	if [[ $- == *x* ]]; then
		set +x
		PAUSE_RESTORE_TRACING_X+='1'
	else
		PAUSE_RESTORE_TRACING_X+='0'
	fi

	if [[ $- == *v* ]]; then
		set +v
		PAUSE_RESTORE_TRACING_V+='1'
	else
		PAUSE_RESTORE_TRACING_V+='0'
	fi
}

function __restore_tracing {
	if [[ -n $PAUSE_RESTORE_TRACING_X ]]; then
		if [[ ${PAUSE_RESTORE_TRACING_X: -1} == '1' ]]; then
			set -x
		fi
		PAUSE_RESTORE_TRACING_X="${PAUSE_RESTORE_TRACING_X:0:${#PAUSE_RESTORE_TRACING_X} - 1}"
	fi
	if [[ -n $PAUSE_RESTORE_TRACING_V ]]; then
		if [[ ${PAUSE_RESTORE_TRACING_V: -1} == '1' ]]; then
			set -v
		fi
		PAUSE_RESTORE_TRACING_V="${PAUSE_RESTORE_TRACING_V:0:${#PAUSE_RESTORE_TRACING_V} - 1}"
	fi
}
__pause_tracing


function __iterate {
	__pause_tracing || return $?
	local ITERATE__lookups=() ITERATE__direction='ascending' ITERATE__seek='' ITERATE__overlap='no' ITERATE__require='' ITERATE__quiet='no' ITERATE__by='' ITERATE__operation='' ITERATE__case=''
	# <single-source helper arguments>
	local ITERATE__item ITERATE__source_variable_name='' ITERATE__targets=() ITERATE__mode=''
	while [[ $# -ne 0 ]]; do
		ITERATE__item="$1"
		shift
		case "$ITERATE__item" in
		'--source={'*'}')
			__affirm_value_is_undefined "$ITERATE__source_variable_name" 'source variable reference' || return $?
			__dereference --source="${ITERATE__item#*=}" --name={ITERATE__source_variable_name} || return $?
			;;
		'--source+target={'*'}')
			ITERATE__item="${ITERATE__item#*=}"
			ITERATE__targets+=("$ITERATE__item")
			__affirm_value_is_undefined "$ITERATE__source_variable_name" 'source variable reference' || return $?
			__dereference --source="$ITERATE__item" --name={ITERATE__source_variable_name} || return $?
			;;
		'--targets='*) __dereference --source="${ITERATE__item#*=}" --append --value={ITERATE__targets} || return $? ;;
		'--target='*) ITERATE__targets+=("${ITERATE__item#*=}") ;;
		'--mode=prepend' | '--mode=append' | '--mode=overwrite' | '--mode=')
			__affirm_value_is_undefined "$ITERATE__mode" 'write mode' || return $?
			ITERATE__mode="${ITERATE__item#*=}"
			;;
		'--append' | '--prepend' | '--overwrite')
			__affirm_value_is_undefined "$ITERATE__mode" 'write mode' || return $?
			ITERATE__mode="${ITERATE__item:2}"
			;;
		'--')
			if [[ -z $ITERATE__source_variable_name ]]; then
				# they are inputs
				if [[ $# -eq 1 ]]; then
					# a string input
					# ITERATE__input="$1"
					# ITERATE__source_variable_name='ITERATE__input'
					# ^ this doesn't allow for recursive sources, whereas the below does
					ITERATE__source_variable_name="ITERATE_${RANDOM}__input"
					eval "local $ITERATE__source_variable_name=\"\$1\"" || return $?
				else
					# an array input
					# ITERATE__inputs=("$@")
					# ITERATE__source_variable_name='ITERATE__inputs'
					# ^ this doesn't allow for recursive sources, whereas the below does
					ITERATE__source_variable_name="ITERATE_${RANDOM}__inputs"
					eval "local $ITERATE__source_variable_name=(\"\$@\")" || return $?
				fi
			else
				# they are needles
				for ITERATE__item in "$@"; do
					ITERATE__lookups+=(--needle="$ITERATE__item")
				done
			fi
			shift $#
			break
			;;
		# </single-source helper arguments>
		# lookups:
		'--value='* | '--needle='* | '--index='* | '--prefix='* | '--suffix='* | '--pattern='* | '--glob='*) ITERATE__lookups+=("$ITERATE__item") ;;
		# order mode
		'--by=lookup' | '--order=lookup' | '--order=argument' | '--lookup') ITERATE__by='lookup' ;;
		'--by=cursor' | '--by=content' | '--order=content' | '--order=source' | '--cursor') ITERATE__by='content' ;;
		# content direction mode
		'--direction=descending' | '--direction=reverse' | '--descending' | '--reverse') ITERATE__direction='descending' ;;
		'--direction=ascending' | '--direction=forward' | '--ascending' | '--forward') ITERATE__direction='ascending' ;; # default
		# seek mode
		'--seek=first' | '--first') ITERATE__seek='first' ;;                                   # only the first match of any needle
		'--seek=each' | '--each') ITERATE__seek='each' ;;                                      # only the first match of each needle
		'--seek=every' | '--seek=multiple' | '--every' | '--multiple') ITERATE__seek='multiple' ;; # all matches of all needles
		# overlap mode
		'--overlap=yes' | '--overlap') ITERATE__overlap='yes' ;;  # for `seek=multiple` string matches, "aaaa" with needles "aa" and "a" will match "aa" 3 times and "a" 4 times, for `seek=each` string matches, "aab" will match needles "aa" 1 time and "ab" 1 time
		'--overlap=no' | '--no-overlap') ITERATE__overlap='no' ;; # for `seek=multiple` string matches, "aaaa" with needles "aa" and "a" will match "aa" twice and "a" 0 times, for `seek=each` string matches, "aab" will match needles "aa" 1 time and "ab" 0 times
		# require mode
		'--require=none' | '--optional') ITERATE__require='none' ;;
		'--require=any' | '--any') ITERATE__require='any' ;;
		'--require=all' | '--all' | '--required') ITERATE__require='all' ;;
		# quiet mode
		'--no-verbose'* | '--verbose'*) __flag --source={ITERATE__item} --target={ITERATE__quiet} --non-affirmative --coerce ;;
		'--no-quiet'* | '--quiet'*) __flag --source={ITERATE__item} --target={ITERATE__quiet} --affirmative --coerce ;;
		# case conversion mode
		'--case='* | '--convert='* | '--conversion='* | '--case-convert='* | '--case-conversion='*) ITERATE__case="${CASE__item#*=}" ;;
		'--upper' | '--uppercase' | '--upper-case') ITERATE__case='upper' ;;
		'--lower' | '--lowercase' | '--lower-case') ITERATE__case='lower' ;;
		'--ignore-case' | '--ignore-case=yes' | '--respect-case=no' | '--case-insensitive' | '--case-insensitive=yes' | '--case-sensitive=no') ITERATE__case='lower' ;;
		'--ignore-case=no' | '--respect-case' | '--respect-case=yes' | '--case-insensitive=no' | '--case-sensitive' | '--case-sensitive=yes') : ;; # no-op
		# operation mode
		'--operation=index' | '--index' | '--indices') ITERATE__operation='index' ;;
		'--operation=has' | '--has')
			ITERATE__operation='has'
			ITERATE__quiet='yes'
			;;
		'--operation=evict' | '--evict') ITERATE__operation='evict' ;;
		# evict on mode
		# '--on=content') ITERATE__on='content' ;;
		# '--on=result') ITERATE__on='result' ;; <-- this would work by wrapping the iteration in a while loop, that checks if there is another iteration to perform, which is enabled when the content is changed in which case the indices and their corresponding variables are regenerated, however, with that complexity, one is probably just wanting the `__replace` function
		# shortcut mode mostly for has/evict
		'--'*) __unrecognised_flag "$ITERATE__item" || return $? ;;
		*) __unrecognised_argument "$ITERATE__item" || return $? ;;
		esac
	done
	local -i ITERATE__lookups_size="${#ITERATE__lookups[@]}"
	__affirm_value_is_defined "$ITERATE__operation" 'operation' || return $?
	__affirm_variable_is_defined "$ITERATE__source_variable_name" 'source variable reference' || return $?
	__affirm_value_is_valid_write_mode "$ITERATE__mode" || return $?
	__affirm_length_defined "$ITERATE__lookups_size" 'lookup' || return $?
	# handle the new automatic inference or failure of inference of various modes
	if [[ -z $ITERATE__seek ]]; then
		if [[ $ITERATE__operation == 'evict' ]]; then
			__print_lines "ERROR: ${FUNCNAME[0]}: The $(__dump --value=evict || :) operation requires an explicit $(__dump --value='{first,each,every}' || :) seek mode." >&2 || :
			__dump {ITERATE__lookups} "{$ITERATE__source_variable_name}" >&2 || :
			return 22 # EINVAL 22 Invalid argument
		elif [[ $ITERATE__require == 'any' ]]; then
			if [[ -z $ITERATE__by ]]; then
				ITERATE__by='cursor' # this default is only done, as it doesn't matter in first/any mode
			fi
			ITERATE__seek='first'
		elif [[ $ITERATE__lookups_size -eq 1 || $ITERATE__require == 'all' ]]; then
			# if all, then default to each, as desiring every is an edge case typically only for evict, which we've already aborted
			ITERATE__seek='each' # first/each are equivalent when there is only one lookup
		else
			__print_lines "ERROR: ${FUNCNAME[0]}: The $(__dump --value="$ITERATE__operation" || :) operation requires an explicit $(__dump --value='{first,each,every}' || :) seek mode when using multiple lookups." >&2 || :
			__dump {ITERATE__lookups} "{$ITERATE__source_variable_name}" >&2 || :
			return 22 # EINVAL 22 Invalid argument
		fi
	fi
	if [[ -z $ITERATE__require ]]; then
		if [[ $ITERATE__seek == 'first' ]]; then
			ITERATE__require='any' # if they are seeking first, then all is a mistake, and none is unlikely
		elif [[ $ITERATE__operation == 'evict' ]]; then
			__print_lines "ERROR: ${FUNCNAME[0]}: The $(__dump --value=evict || :) operation requires an explicit $(__dump --value='{optional,any,all}' || :) require mode." >&2 || :
			__dump {ITERATE__lookups} "{$ITERATE__source_variable_name}" >&2 || :
			return 22 # EINVAL 22 Invalid argument
		elif [[ $ITERATE__lookups_size -eq 1 ]]; then
			ITERATE__require='any' # any/all are equivalent when there is only one lookup
		elif [[ $ITERATE__operation == 'has' ]]; then
			__print_lines "ERROR: ${FUNCNAME[0]}: $(__dump --value=has || :) operation requires an explicit $(__dump --value='{any,all}' || :) require mode when using multiple lookups." >&2 || :
			__dump {ITERATE__lookups} "{$ITERATE__source_variable_name}" >&2 || :
			return 22 # EINVAL 22 Invalid argument
		else
			ITERATE__require='all'
		fi
	fi
	if [[ -z $ITERATE__by ]]; then
		ITERATE__by='lookup'
	fi
	# sanity checks
	__affirm_value_is_defined "$ITERATE__by" 'by mode' || return $?
	__affirm_value_is_defined "$ITERATE__seek" 'seek mode' || return $?
	__affirm_value_is_defined "$ITERATE__require" 'require mode' || return $?
	# ensure that if multiple lookups were specified, it can't be all and first
	if [[ $ITERATE__lookups_size -gt 1 && $ITERATE__require == 'all' && $ITERATE__seek == 'first' ]]; then
		__print_lines "ERROR: ${FUNCNAME[0]}: The $(__dump --value=first || :) seek mode cannot be used with the $(__dump --value=all || :) require mode when multiple lookups are specified, as such would always fail." >&2 || :
		__dump {ITERATE__lookups} "{$ITERATE__source_variable_name}" >&2 || :
		return 22 # EINVAL 22 Invalid argument
	fi
	# get the indices
	local ITERATE__indices=()
	__indices --source="{$ITERATE__source_variable_name}" --target={ITERATE__indices} || return $?
	# affirm there are indices available
	local -i ITERATE__size="${#ITERATE__indices[@]}"
	if [[ $ITERATE__size -eq 0 ]]; then
		case "$ITERATE__operation" in
		has) return 1 ;;
		evict)
			__to --source="{$ITERATE__source_variable_name}" --mode="$ITERATE__mode" --targets={ITERATE__targets} || return $?
			return 0
			;;
		esac
		__affirm_length_defined "$ITERATE__size" 'source' || {
			local -i ITERATE__exit_status="$?"
			__dump {ITERATE__source_variable_name} {ITERATE__targets} {ITERATE__operation} {ITERATE__lookups} >&2 || :
			return "$ITERATE__exit_status"
		}
	fi
	# get the first and last indices for use with prefix/suffix
	# trunk-ignore(shellcheck/SC2124)
	local -i ITERATE__first_in_whole="${ITERATE__indices[0]}" ITERATE__last_in_whole="${ITERATE__indices[@]: -1}"
	# reverse the indices if desired
	if [[ $ITERATE__direction == 'descending' ]]; then
		__reverse --source+target={ITERATE__indices} || return $?
	fi
	# get the first and last indices for use with pattern/glob
	local -i ITERATE__first_in_order="${ITERATE__indices[0]}" # ITERATE__last_in_order="${ITERATE__indices[@]: -1}"
	# prepare array awareness
	local ITERATE__array
	if __is_array "$ITERATE__source_variable_name"; then
		ITERATE__array=yes
		# if we are an array, validate what can be empty and what cannot be
		for ITERATE__item in "${ITERATE__lookups[@]}"; do
			if [[ -z ${ITERATE__item#*=} ]]; then
				case "$ITERATE__item" in
				# we can lookup empty array elements
				'--value='* | '--needle='*) : ;;

				# these lookups make no sense if they are empty
				'--prefix='* | '--suffix='* | '--pattern='* | '--glob='*)
					__print_lines "ERROR: ${FUNCNAME[0]}: The $(__dump --value="$ITERATE__item" || :) option must not have an empty value." >&2 || :
					__dump {ITERATE__lookups} "{$ITERATE__source_variable_name}" >&2 || :
					return 22 # EINVAL 22 Invalid argument
					;;

				# invalid lookup
				*) __unrecognised_flag "$ITERATE__item" || return $? ;;
				esac
			fi
		done
	else
		ITERATE__array=no
		# if we are a string, ensure no empty lookups, as none of them make sense if empty
		for ITERATE__item in "${ITERATE__lookups[@]}"; do
			if [[ -z ${ITERATE__item#*=} ]]; then
				__print_lines "ERROR: ${FUNCNAME[0]}: The $(__dump --value="$ITERATE__item" || :) option must not have an empty value when the input is a string." >&2 || :
				__dump {ITERATE__lookups} "{$ITERATE__source_variable_name}" >&2 || :
				return 22 # EINVAL 22 Invalid argument
			fi
		done
	fi
	# because our comparison reference can be different based on case modification, setup a new variable
	# this is because if we are comparing ignoring case, we still want to return the original case sensitive result
	local ITERATE__compare_source_reference="$ITERATE__source_variable_name"
	if [[ -n $ITERATE__case ]]; then
		# convert the source reference
		if [[ $ITERATE__array == 'yes' ]]; then
			ITERATE__compare_source_reference="ITERATE_${RANDOM}__inputs__${ITERATE__case}"
			eval "local $ITERATE__compare_source_reference=()" || return $?
			__case --conversion="$ITERATE__case" --source="{$ITERATE__source_variable_name}" --target="{$ITERATE__compare_source_reference}"
		else
			ITERATE__compare_source_reference="ITERATE_${RANDOM}__input__${ITERATE__case}"
			eval "local $ITERATE__compare_source_reference=''" || return $?
			__case --conversion="$ITERATE__case" --source="{$ITERATE__source_variable_name}" --target="{$ITERATE__compare_source_reference}"
		fi
		# convert lookups
		__case --conversion="$ITERATE__case" --source+target={ITERATE__lookups}
	fi
	# iterate
	local -i ITERATE__outer ITERATE__inner ITERATE__index ITERATE__lookup_index ITERATE__lookup_size ITERATE__match_index ITERATE__match_size ITERATE__overlap_index ITERATE__break
	local ITERATE__results=() ITERATE__consumed_indices_map=() ITERATE__consumed_lookups_map=() ITERATE__lookups_indices=("${!ITERATE__lookups[@]}") ITERATE__value ITERATE__lookup_option ITERATE__lookup ITERATE__match ITERATE__matched
	if [[ $ITERATE__by == 'lookup' ]]; then
		ITERATE__outers=("${ITERATE__lookups_indices[@]}")
		ITERATE__inners=("${ITERATE__indices[@]}")
	else
		ITERATE__outers=("${ITERATE__indices[@]}")
		ITERATE__inners=("${ITERATE__lookups_indices[@]}")
	fi
	function __is_string_overlapped {
		if [[ $ITERATE__overlap == 'no' ]]; then
			for ((ITERATE__overlap_index = ITERATE__match_index; ITERATE__overlap_index < ITERATE__match_index + ITERATE__lookup_size; ITERATE__overlap_index++)); do
				if [[ -n ${ITERATE__consumed_indices_map[ITERATE__overlap_index]-} ]]; then
					return 0
				fi
			done
		fi
		return 1
	}
	for ITERATE__outer in "${ITERATE__outers[@]}"; do
		for ITERATE__inner in "${ITERATE__inners[@]}"; do
			# adjust for our iteration mode
			if [[ $ITERATE__by == 'lookup' ]]; then
				ITERATE__lookup_index="$ITERATE__outer" ITERATE__index="$ITERATE__inner"
			else
				ITERATE__index="$ITERATE__outer" ITERATE__lookup_index="$ITERATE__inner"
			fi
			# has this lookup index or content index already been consumed? these maps are always updated, regardless of modes
			if [[ $ITERATE__overlap == 'no' && -n ${ITERATE__consumed_indices_map[ITERATE__index]-} ]] || [[ $ITERATE__seek == 'each' && -n ${ITERATE__consumed_lookups_map[ITERATE__lookup_index]-} ]]; then
				continue
			fi
			# handle the lookup
			ITERATE__lookup_option="${ITERATE__lookups[ITERATE__lookup_index]}" ITERATE__match='' ITERATE__matched=no ITERATE__value='' ITERATE__match_index=$ITERATE__index ITERATE__break=0
			ITERATE__lookup="${ITERATE__lookup_option#*=}"
			case "$ITERATE__lookup_option" in
			'--value='* | '--needle='*)
				# exact match
				if [[ $ITERATE__array == 'yes' ]]; then
					eval 'ITERATE__value=${'"$ITERATE__compare_source_reference"'[ITERATE__index]}' || return $?
				else
					ITERATE__lookup_size=${#ITERATE__lookup}
					if [[ $ITERATE__direction == 'ascending' ]]; then
						# ascending, so we need to look right-ways
						if [[ $((ITERATE__match_index + ITERATE__lookup_size)) -le $ITERATE__size ]]; then
							# when not overlapping, validate none of the indices have been consumed
							if __is_string_overlapped; then
								continue
							fi
							# valid, note the match value
							eval 'ITERATE__value="${'"$ITERATE__compare_source_reference"':ITERATE__match_index:ITERATE__lookup_size}"' || return $?
						else
							continue
						fi
					else
						# descending, so we need to look left-ways
						ITERATE__match_index=$((ITERATE__index - ITERATE__lookup_size + 1)) # +1 to include the current character
						if [[ $ITERATE__match_index -ge 0 ]]; then
							# when not overlapping, validate none of the indices have been consumed
							if __is_string_overlapped; then
								continue
							fi
							# valid, note the match value
							eval 'ITERATE__value="${'"$ITERATE__compare_source_reference"':ITERATE__match_index:ITERATE__lookup_size}"' || return $?
						else
							continue
						fi
					fi
				fi
				if [[ $ITERATE__value == "$ITERATE__lookup" ]]; then
					ITERATE__matched=yes
					ITERATE__match="$ITERATE__value" # substring match
					ITERATE__consumed_lookups_map[ITERATE__lookup_index]="$ITERATE__index"
				else
					continue
				fi
				;;
			'--index='*)
				# index match
				ITERATE__lookup_size=1
				if [[ $ITERATE__array == 'yes' ]]; then
					eval 'ITERATE__value=${'"$ITERATE__compare_source_reference"'[ITERATE__index]}' || return $?
				else
					eval 'ITERATE__value="${'"$ITERATE__compare_source_reference"':ITERATE__index:1}"' || return $?
				fi
				if [[ $ITERATE__index == "$ITERATE__lookup" ]]; then
					ITERATE__matched=yes
					ITERATE__match="$ITERATE__value"
					ITERATE__consumed_lookups_map[ITERATE__lookup_index]="$ITERATE__index"
				else
					continue
				fi
				;;
			'--prefix='*)
				# prefix match
				ITERATE__lookup_size=${#ITERATE__lookup}
				if [[ $ITERATE__array == 'yes' ]]; then
					eval 'ITERATE__value=${'"$ITERATE__compare_source_reference"'[ITERATE__index]:0:ITERATE__lookup_size}' || return $?
				elif [[ $ITERATE__index -eq $ITERATE__first_in_whole ]]; then # only match when we are at the first in whole index
					# when not overlapping, validate none of the indices have been consumed
					if __is_string_overlapped; then
						continue
					fi
					# valid, note the match value
					eval 'ITERATE__value="${'"$ITERATE__compare_source_reference"':0:ITERATE__lookup_size}"' || return $?
				else
					continue
				fi
				if [[ $ITERATE__value == "$ITERATE__lookup" ]]; then
					ITERATE__matched=yes
					ITERATE__match="$ITERATE__value" # substring match
					ITERATE__consumed_lookups_map[ITERATE__lookup_index]="$ITERATE__index"
				else
					continue
				fi
				;;
			'--suffix='*)
				# suffix match
				ITERATE__lookup_size=${#ITERATE__lookup}
				if [[ $ITERATE__array == 'yes' ]]; then
					eval 'ITERATE__value=${'"$ITERATE__compare_source_reference"'[ITERATE__index]: -ITERATE__lookup_size}' || return $?
				elif [[ $ITERATE__index -eq $ITERATE__last_in_whole ]]; then         # only match once when we are at the last in whole index
					ITERATE__match_index=$((ITERATE__index - ITERATE__lookup_size + 1)) # +1 to include the current character# when not overlapping, validate none of the indices have been consumed
					if __is_string_overlapped; then
						continue
					fi
					# valid, note the match value
					eval 'ITERATE__value="${'"$ITERATE__compare_source_reference"':ITERATE__match_index}"' || return $?
				else
					continue
				fi
				if [[ $ITERATE__value == "$ITERATE__lookup" ]]; then
					ITERATE__matched=yes
					ITERATE__match="$ITERATE__value" # substring match
					ITERATE__consumed_lookups_map[ITERATE__lookup_index]="$ITERATE__index"
				else
					continue
				fi
				;;
			'--pattern='*)
				# pattern match: POSIX extended regular expression
				if [[ $ITERATE__array == 'yes' ]]; then
					eval 'ITERATE__value=${'"$ITERATE__compare_source_reference"'[ITERATE__index]}' || return $?
				elif [[ $ITERATE__index -eq $ITERATE__first_in_order ]]; then
					# whole string match
					eval 'ITERATE__value="${'"$ITERATE__compare_source_reference"'}"' || return $?
				else
					continue
				fi
				if [[ $ITERATE__value =~ $ITERATE__lookup ]] && [[ -n ${BASH_REMATCH[0]-} ]]; then # workaround a bash bug
					ITERATE__matched=yes
					ITERATE__match="$ITERATE__value" # whole string match
					ITERATE__consumed_lookups_map[ITERATE__lookup_index]="$ITERATE__index"
				else
					continue
				fi
				;;
			'--glob='*)
				# pattern match
				if [[ $ITERATE__array == 'yes' ]]; then
					eval 'ITERATE__value=${'"$ITERATE__compare_source_reference"'[ITERATE__index]}' || return $?
				elif [[ $ITERATE__index -eq $ITERATE__first_in_order ]]; then
					# whole string match
					eval 'ITERATE__value="${'"$ITERATE__compare_source_reference"'}"' || return $?
				else
					continue
				fi
				# trunk-ignore(shellcheck/SC2053)
				if [[ $ITERATE__value == $ITERATE__lookup ]]; then
					ITERATE__matched=yes
					ITERATE__match="$ITERATE__value" # whole string match
					ITERATE__consumed_lookups_map[ITERATE__lookup_index]="$ITERATE__index"
				else
					continue
				fi
				;;

			# invalid lookup
			*) __unrecognised_flag "$ITERATE__lookup_option" || return $? ;;
			esac
			if [[ $ITERATE__matched == 'yes' ]]; then
				# for eviction, keep this for the overlap and breaking modifications, even though the results array doesn't matter for eviction
				if [[ $ITERATE__seek == 'multiple' ]]; then
					ITERATE__results+=("$ITERATE__match_index")
				elif [[ $ITERATE__seek == 'each' ]]; then
					ITERATE__results[ITERATE__lookup_index]="$ITERATE__match_index"
					if [[ ${#ITERATE__results[@]} -eq $ITERATE__lookups_size ]]; then
						ITERATE__break=2 # finished, break the outer loop
					fi
				else
					# first
					ITERATE__results+=("$ITERATE__match_index")
					ITERATE__break=2 # finished, break the outer loop
				fi
				# note the consumed indices,
				# this is utilised by our entrance overlap check (as our no overlap skips consumed indices), or by our exit when evicting (as the evict result evicts consumed indices)
				if [[ $ITERATE__overlap == 'no' || $ITERATE__operation == 'evict' ]]; then
					if [[ $ITERATE__array == 'yes' ]]; then
						ITERATE__consumed_indices_map["$ITERATE__match_index"]="$ITERATE__lookup_index"
					else
						ITERATE__match_size=${#ITERATE__match}
						for ((ITERATE__overlap_index = ITERATE__match_index; ITERATE__overlap_index < ITERATE__match_index + ITERATE__match_size; ITERATE__overlap_index++)); do
							ITERATE__consumed_indices_map["$ITERATE__overlap_index"]="$ITERATE__lookup_index"
						done
					fi
				fi
				# handle the break now, so that the overlap eviction above takes effect
				if [[ $ITERATE__break -ne 0 ]]; then
					break "$ITERATE__break"
				fi
			fi
		done
	done
	# any/all require checks
	local -i ITERATE__found_size="${#ITERATE__consumed_lookups_map[@]}"
	# if we are eviction, then generate the eviction result
	if [[ $ITERATE__operation == 'evict' ]]; then
		ITERATE__results=()
		if [[ $ITERATE__array == 'yes' ]]; then
			for ITERATE__index in "${ITERATE__indices[@]}"; do
				if [[ -n ${ITERATE__consumed_indices_map[ITERATE__index]-} ]]; then
					# this index was consumed, so skip it
					continue
				fi
				eval 'ITERATE__results+=("${'"$ITERATE__source_variable_name"'[ITERATE__index]}")' || return $?
			done
		else
			local ITERATE__result=''
			for ITERATE__index in "${ITERATE__indices[@]}"; do
				if [[ -n ${ITERATE__consumed_indices_map[ITERATE__index]-} ]]; then
					# this index was consumed, so skip it
					continue
				fi
				eval 'ITERATE__result+="${'"$ITERATE__source_variable_name"':ITERATE__index:1}"' || return $?
			done
			ITERATE__results+=("$ITERATE__result")
		fi
	fi
	# validate has mode
	if [[ $ITERATE__operation == 'has' && $ITERATE__require == 'none' ]]; then
		__print_lines "ERROR: ${FUNCNAME[0]}: The operation $(__dump --value=has || :) cannot be used with the require mode $(__dump --value=none || :), use $(__dump --value=any || :) or $(__dump --value=all || :) or there is no point." >&2 || :
		return 22 # EINVAL 22 Invalid argument
	fi
	# validate first mode
	if [[ $ITERATE__seek == 'first' && $ITERATE__found_size -gt 1 ]]; then
		__print_lines "ERROR: ${FUNCNAME[0]}: Too many lookups were found, expected $(__dump --value="1" || :) but found $(__dump --value="$ITERATE__found_size" || :):" >&2 || :
		__dump {ITERATE__lookups} {ITERATE__consumed_lookups_map} {ITERATE__results} "{$ITERATE__source_variable_name}" >&2 || :
		return 34 # ERANGE 34 Result too large
	fi
	# any/all require checks
	if [[ $ITERATE__require == 'any' ]]; then
		if [[ $ITERATE__found_size -eq 0 ]]; then
			if [[ $ITERATE__quiet == 'no' ]]; then
				__print_lines "ERROR: ${FUNCNAME[0]}: No lookups were found, expected at least $(__dump --value='1' || :) but found $(__dump --value="$ITERATE__found_size" || :):" >&2 || :
				__dump {ITERATE__lookups} {ITERATE__consumed_lookups_map} {ITERATE__results} "{$ITERATE__source_variable_name}" >&2 || :
			fi
			return 33 # EDOM 33 Numerical argument out of domain
		fi
	elif [[ $ITERATE__require == 'all' ]]; then
		if [[ $ITERATE__found_size -ne ITERATE__lookups_size ]]; then
			if [[ $ITERATE__quiet == 'no' ]]; then
				__print_lines "ERROR: ${FUNCNAME[0]}: Not all lookups were found, expected $(__dump --value="$ITERATE__lookups_size" || :) but found $(__dump --value="$ITERATE__found_size" || :):" >&2 || :
				__dump {ITERATE__lookups} {ITERATE__consumed_lookups_map} {ITERATE__results} "{$ITERATE__source_variable_name}" >&2 || :
			fi
			return 33 # EDOM 33 Numerical argument out of domain
		fi
	fi
	# send the appropriate result based on the operation
	if [[ $ITERATE__operation == 'has' ]]; then
		# failure checks already happened above for has, so we can just return 0
		return 0
	fi
	# send the results
	__to --source={ITERATE__results} --mode="$ITERATE__mode" --targets={ITERATE__targets} || return $?
	__restore_tracing || return $?
}
function __index {
	__iterate --index "$@" || return $?
}
function __has {
	__iterate --has "$@" || return $?
}
function __evict {
	__iterate --evict "$@" || return $?
}

__iterate "$@"
