# Environment variables

RSPAMD_LOG_LEVEL (default: notice)

RSPAMD_REDIS_HOST
RSPAMD_DNS_HOST

RSPAMD_DKIM_DEFAULT_SELECTOR (uses keys from /etc/rspamd/dkim/)
RSPAMD_DKIM_DOMAINS_SELECTORS (uses keys from /etc/rspamd/dkim/) (cf. <https://docs.rspamd.com/modules/dkim_signing#using-maps>)

RSPAMD_ARC_DEFAULT_SELECTOR (uses keys from /etc/rspamd/arc/)
RSPAMD_ARC_DOMAINS_SELECTORS (uses keys from /etc/rspamd/arc/) (cf. <https://docs.rspamd.com/modules/arc#using-maps-for-selectors-and-paths>)
