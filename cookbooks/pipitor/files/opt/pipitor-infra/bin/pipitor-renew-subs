#!/bin/bash

# Renew subscriptions that will expire within `MARGIN` seconds.
MARGIN=$(((60 * 60 * 24) * 3 / 2)) # 1.5 days
# Rate limit parameters for WebSub hubs (wild guess):
LIMIT=30
WINDOW=10

set -o errexit -o nounset

now="$(date +%s)"
threshold=$((now + MARGIN))

if ! [ -f pipitor.sqlite3 ]; then
	# shellcheck disable=SC2016
	echo 'Missing `./pipitor.sqlite3`' >&2
	exit 1
fi

expiring_exists() {
	sqlite3 pipitor.sqlite3 <<-SQL
	SELECT EXISTS(
		SELECT *
		FROM websub_active_subscriptions
		WHERE expires_at <= ${threshold} AND expires_at <> ${now}
	);
	SQL
}

dangling_exists() {
	sqlite3 pipitor.sqlite3 <<-SQL
	SELECT EXISTS(
		SELECT * FROM
		websub_subscriptions
		WHERE id NOT IN (
			SELECT id
			FROM websub_active_subscriptions
		)
	);
	SQL
}

if (($(expiring_exists))); then
	while true; do
		# Set `expires_at` value of expiring subscriptions to the current timestamp
		# to force the bot to recognize the subscriptions as expiring.
		sqlite3 pipitor.sqlite3 <<-SQL
		UPDATE websub_active_subscriptions
		SET expires_at = ${now}
		WHERE id IN (
			SELECT id
			FROM websub_active_subscriptions
			WHERE expires_at <= ${threshold}
			ORDER BY expires_at ASC
			LIMIT ${LIMIT}
		);
		SQL
		# Shut down the bot and let systemd restart it.
		# The bot will renew the expiring subscriptions upon restart.
		/usr/local/bin/pipitor ctl shutdown

		if ! (($(expiring_exists))); then
			break
		fi

		sleep "${WINDOW}"
	done
fi

# The renewal of subscriptions above may fail due to rate limit or something.
# Delete such subscriptions and let the bot re-subscribe them.
wait=5
retry=10
sleep "${wait}" # Wait a moment for the WebSub hub servers to confirm the subscriptions.
while (($(dangling_exists))); do
	sleep $((WINDOW - wait))

	sqlite3 pipitor.sqlite3 <<-SQL
	PRAGMA foreign_keys=ON;
	DELETE FROM websub_subscriptions
	WHERE id NOT IN (
		SELECT id
		FROM websub_active_subscriptions
	)
	LIMIT ${LIMIT};
	SQL
	/usr/local/bin/pipitor ctl reload

	retry=$((retry - 1))
	if ! ((retry)); then
		echo 'Reached the maximum number of attempts while re-subscribing dangling subscriptions'
		exit 1
	fi

	sleep "${wait}"
done
