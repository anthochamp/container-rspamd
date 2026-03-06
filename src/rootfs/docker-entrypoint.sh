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
export RSPAMD_CONTROLLER_PASSWORD="${RSPAMD_CONTROLLER_PASSWORD:-}"
export RSPAMD_DKIM_DEFAULT_SELECTOR="${RSPAMD_DKIM_DEFAULT_SELECTOR:-}"
export RSPAMD_DKIM_DOMAINS_SELECTORS="${RSPAMD_DKIM_DOMAINS_SELECTORS:-}"
export RSPAMD_ARC_DEFAULT_SELECTOR="${RSPAMD_ARC_DEFAULT_SELECTOR:-}"
export RSPAMD_ARC_DOMAINS_SELECTORS="${RSPAMD_ARC_DOMAINS_SELECTORS:-}"

# DMARC Reporting
export RSPAMD_DMARC_REPORTING_ENABLED="${RSPAMD_DMARC_REPORTING_ENABLED:-0}"
export RSPAMD_DMARC_REPORTING_FROM="${RSPAMD_DMARC_REPORTING_FROM:-}"
export RSPAMD_DMARC_REPORTING_ORG_NAME="${RSPAMD_DMARC_REPORTING_ORG_NAME:-}"
export RSPAMD_DMARC_REPORTING_DOMAIN="${RSPAMD_DMARC_REPORTING_DOMAIN:-}"
export RSPAMD_DMARC_REPORTING_SMTP_HOST="${RSPAMD_DMARC_REPORTING_SMTP_HOST:-}"
export RSPAMD_DMARC_REPORTING_SMTP_PORT="${RSPAMD_DMARC_REPORTING_SMTP_PORT:-587}"
export RSPAMD_DMARC_REPORTING_SMTP_USERNAME="${RSPAMD_DMARC_REPORTING_SMTP_USERNAME:-}"
export RSPAMD_DMARC_REPORTING_SMTP_PASSWORD="${RSPAMD_DMARC_REPORTING_SMTP_PASSWORD:-}"
export RSPAMD_DMARC_REPORTING_SMTP_TLS="${RSPAMD_DMARC_REPORTING_SMTP_TLS:-starttls}"

# Fuzzy Storage
export RSPAMD_FUZZY_STORAGE_KEY="${RSPAMD_FUZZY_STORAGE_KEY:-}"
export RSPAMD_FUZZY_UPSTREAM_ENABLED="${RSPAMD_FUZZY_UPSTREAM_ENABLED:-0}"

# URL Redirector
export RSPAMD_URL_REDIRECTOR_ENABLED="${RSPAMD_URL_REDIRECTOR_ENABLED:-0}"
export RSPAMD_URL_REDIRECTOR_MAX_REDIRECTS="${RSPAMD_URL_REDIRECTOR_MAX_REDIRECTS:-5}"
export RSPAMD_URL_REDIRECTOR_TIMEOUT="${RSPAMD_URL_REDIRECTOR_TIMEOUT:-10}"
export RSPAMD_URL_REDIRECTOR_NESTED_LIMIT="${RSPAMD_URL_REDIRECTOR_NESTED_LIMIT:-5}"

j2Templates="
/etc/rspamd/local.d/arc.conf
/etc/rspamd/local.d/classifier-bayes.conf
/etc/rspamd/local.d/dkim_signing.conf
/etc/rspamd/local.d/dmarc.conf
/etc/rspamd/local.d/fuzzy_check.conf
/etc/rspamd/local.d/greylist.conf
/etc/rspamd/local.d/history_redis.conf
/etc/rspamd/local.d/logging.inc
/etc/rspamd/local.d/neural.conf
/etc/rspamd/local.d/options.inc
/etc/rspamd/local.d/redis.conf
/etc/rspamd/local.d/reputation.conf
/etc/rspamd/local.d/url_redirector.conf
/etc/rspamd/local.d/worker-controller.inc
/etc/rspamd/local.d/worker-fuzzy.inc
/etc/rspamd/arc_selectors.map
/etc/rspamd/dkim_selectors.map
"

for file in $j2Templates; do
	export | /root/.local/bin/jinja2 --format env -o "$file" "$file.j2"

	chmod --reference="$file.j2" "$file"
	chown --reference="$file.j2" "$file"
done

# ensure mounted volumes owners
chown -R root:root /etc/rspamd/dkim || true
chown -R root:root /etc/rspamd/arc || true
chown -R _rspamd:_rspamd /var/lib/rspamd || true

exec "$@"
