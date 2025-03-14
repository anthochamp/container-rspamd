#!/usr/bin/env sh
set -eu

# shellcheck disable=SC2120,SC3043
replaceEnvSecrets() {
	# replaceEnvSecrets 1.0.0
	# https://gist.github.com/anthochamp/d4d9537f52e5b6c42f0866dd823a605f
	local prefix="${1:-}"

	for envSecretName in $(export | awk '{print $2}' | grep -oE '^[^=]+' | grep '__FILE$'); do
		if [ -z "$prefix" ] || printf '%s' "$envSecretName" | grep "^$prefix" >/dev/null; then
			local envName
			envName=$(printf '%s' "$envSecretName" | sed 's/__FILE$//')

			local filePath
			filePath=$(eval echo '${'"$envSecretName"':-}')

			if [ -n "$filePath" ]; then
				if [ -f "$filePath" ]; then
					echo Using content from "$filePath" file for "$envName" environment variable value.

					export "$envName"="$(cat -A "$filePath")"
					unset "$envSecretName"
				else
					echo ERROR: Environment variable "$envSecretName" is defined but does not point to a regular file. 1>&2
					exit 1
				fi
			fi
		fi
	done
}

replaceEnvSecrets RSPAMD_

export RSPAMD_LOG_LEVEL="${RSPAMD_LOG_LEVEL:-notice}"
export RSPAMD_REDIS_HOST="${RSPAMD_REDIS_HOST:-}"
export RSPAMD_DNS_HOST="${RSPAMD_DNS_HOST:-}"
export RSPAMD_DKIM_DEFAULT_SELECTOR="${RSPAMD_DKIM_DEFAULT_SELECTOR:-}"
export RSPAMD_DKIM_DOMAINS_SELECTORS="${RSPAMD_DKIM_DOMAINS_SELECTORS:-}"

j2Templates="
/etc/rspamd/local.d/classifier-bayes.conf
/etc/rspamd/local.d/dkim_signing.conf
/etc/rspamd/local.d/greylist.conf
/etc/rspamd/local.d/history_redis.conf
/etc/rspamd/local.d/logging.inc
/etc/rspamd/local.d/options.inc
/etc/rspamd/local.d/redis.conf
/etc/rspamd/dkim_selectors.map
"

for file in $j2Templates; do
	/root/.local/bin/jinja2 -o "$file" "$file.j2"

	chmod --reference="$file.j2" "$file"
	chown --reference="$file.j2" "$file"
done

# ensure mounted volumes owners
chown -R root:root /etc/rspamd/dkim || true
chown -R _rspamd:_rspamd /var/lib/rspamd || true

exec "$@"
