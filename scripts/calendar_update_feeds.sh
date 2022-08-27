#!/bin/bash

set -o errexit -o nounset

commit_author='The Japari Archives LB System <ursus.cauda.elongata+archives@gmail.com>'
signing_key='F02E317A1C3EF485AC547835CB02707D7944B297'

channels=(
	UCEOugXOAfa-HRmRjKbH8z3Q
	UCEcMIuGR8WO2TwL9XIpjKtw
	UCmYO-WfY7Tasry4D1YB4LJw
	UCMpw36mXEu3SLsqdrJxUKNA
	UCabMjG8p6G5xLkPJgEoTnDg
	UCdNBhcAohYjXlUVYsz8X2KQ
	UCxm7yNjJsSvyvcG96-Cvmpw
	UCNObi6xvj6QeZ0g7BhAbF7w
	UCYa58DdXGAGMJQHqTxi-isA
)

git fetch origin main
git checkout origin/main

./scripts/sync_yt.rb "${channels[@]}" < "$1"
./scripts/paginate.rb "${channels[@]}"

git add feed/{*,\*}.json data/{*,\*}.{json,xml}

if ! git diff HEAD --quiet; then
	git commit --author="$commit_author" -S"$signing_key" -m 'chore: update feeds'
	git push origin +HEAD:refs/heads/main
fi
