FROM rspamd/rspamd:3.13.0@sha256:98c226bc6c5a60c8437042b33b96926f37b54dca4a85181471312b0c62df4137

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

# 11332 (worker proxy), 11334 (controller)
EXPOSE 11332 11334

VOLUME ["/etc/rspamd/dkim/", "/var/lib/rspamd/"]

COPY --chmod=755 /rootfs/docker-entrypoint.sh /

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD [ "rspamd", "-f", "-u", "_rspamd", "-g", "_rspamd" ]

HEALTHCHECK \
	CMD rspamc uptime || exit 1
