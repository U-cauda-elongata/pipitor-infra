#!/usr/bin/env bash

set -e

PATH="/usr/local/bin:${PATH}"

IFS=$'\t' read -r repo run_id run_name conclusion \
< <(jq -r '[.repository.full_name, .check_run.id, .check_run.name, .check_run.conclusion] | @tsv')

# shellcheck disable=SC2016
if [ "${run_name}" = 'Generate `Pipitor.json`' ] && [ "${conclusion}" = 'success' ]; then
	cd "${HOME}/KF_pipitor-resources"
	curl -fLSs "https://api.github.com/repos/${repo}/actions/runs/${run_id}/artifacts" \
	| jq -r '.artifacts | map(select(.name == "Pipitor.json")) | .[0].url' \
	| xargs curl -fLSs -o Pipitor.json
	pipitor twitter-list-sync & pipitor ctl reload
fi
