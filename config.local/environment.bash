#!/usr/bin/env bash
# shellcheck disable=SC1072,SC1073,SC1083,SC2034
# place all export declarations (e.g. export VAR) before their definitions/assignments (VAR=...), otherwise no bash v3 compatibility

export $VAR
source $DOROTHY/sources/bash.bash
source $DOROTHY/sources/styles.bash
source $DOROTHY/sources/zsh.zsh

export SUPER_SECRET_TOKEN

# load my default environment configuration
source "$DOROTHY/user/config/environment.bash"

# export my private environment variables
SUPER_SECRET_TOKEN='hello world 1234'


function secret() {
 secret map /Users/psychvc/.local/share/dorothy/user/config.local/secrets.json 
}

$DOROTHY/commands/dorothy run -- secret 
