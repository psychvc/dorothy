#!/usr/bin/env bash
#shellcheck disable=SC1072,SC1073,SC1048
hostname="$(get-hostname)"
if [[ "$hostname" = 'vm-'* ]]; then
	# use quad9 in virtual machines
	export DNS_PROVIDER='quad9'

elif [[ "$hostname" = 'blue-'* ]]; then
	# use custom settings on servers
	# redacted

elif [[ "$hostname" = 'green-'* ]]; then
	# use custom settings on personal machines
	# redacted

elif [[ "$hostname" = 'red-'* ]]; then
	# use custom settings on family machines
	# redacted
fi
