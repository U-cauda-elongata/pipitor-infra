#!/bin/sh

set -e

PATH="/usr/local/bin:${PATH}"

if jq --exit-status '
	.["check_run"]
	| [.["name"] == "Check Dhall file", .["conclusion"] == "success"]
	| all
' > /dev/null
then
	cd "${HOME}/KF_pipitor-resources"
	git fetch
	git rebase origin/master
	dhall-to-json --compact --file Pipitor.dhall --output Pipitor.json
	pipitor twitter-list-sync & pipitor ctl reload
fi
