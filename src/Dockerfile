FROM rspamd/rspamd:4.0.1@sha256:d35a5c8367e98df7d8fd0c3c91e3b2d75a78bc82a9fbb0780d5c15f966ddd1c5

# rspamd sets user/group to _rspamd:_rspamd
# We need root access on Dockerfile & docker-entrypoint.sh, lets put back
# initial user 0 and we'll execute pgadmin later with runuser.
# hadolint ignore=DL3002
USER 0

# hadolint ignore=DL3008
RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends pipx; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*

# hadolint ignore=DL3013
RUN pipx install jinja2-cli

COPY --chmod=644 /rootfs/config /etc/rspamd/

# 11332 (worker proxy - milter protocol)
# 11334 (controller - WebUI and API)
# 11335 (fuzzy storage)
EXPOSE 11332 11334 11335

VOLUME ["/etc/rspamd/arc/", "/etc/rspamd/dkim/", "/var/lib/rspamd/"]

COPY --chmod=755 /rootfs/docker-entrypoint.sh /

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD ["/usr/bin/rspamd", "-f", "-u", "_rspamd", "-g", "_rspamd"]

HEALTHCHECK \
	CMD rspamc uptime || exit 1
