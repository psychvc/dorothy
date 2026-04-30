#!/usr/bin/env bash
# shellcheck disable=SC2034
# Used by `setup-git`, `ssh-helper`, use `--configure` to (re)configure this
# Do not use `export` keyword in this file

GPG_SIGNING_KEY=''
GPG_SIGNING_AGENT=op
SSH_IDENTITY_AGENT=op

GIT_DEFAULT_BRANCH=main
GIT_PROTOCOL=https
GIT_NAME="Chatpong Vornartaksorn"
GIT_EMAIL=chatpong.dvm@gmail.com
MERGE_TOOL=diff
GITHUB_USERNAME=psychvc
GITLAB_USERNAME=psychvc
