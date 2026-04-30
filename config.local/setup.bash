#!/usr/bin/env bash

hostname="$(get-hostname)"
if [[ "$hostname" != 'vm-'* ]]; then
	source "$DOROTHY/user/config/setup.bash"
fi


