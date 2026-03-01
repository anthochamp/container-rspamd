FROM rspamd/rspamd:3.14.3@sha256:b2fc96714bc4e376c87c5f2ee405f6edcc7acaa10b1ad04e023c4854ef47c6fc

# rspamd sets user/group to _rspamd:_rspamd
# We need root access on Dockerfile & docker-entrypoint.sh, lets put back
# initial user 0 and we'll execute pgadmin later with runuser.
# hadolint ignore=DL3002
USER 0

# hadolint ignore=DL3008
RUN set -ex; \
	apt-get update; \
	apt-get install -y --no-install-recommends pipx stunnel4 supervisor; \
	apt-get clean; \
	rm -rf /var/lib/apt/lists/*; \
	mkdir -p /run/stunnel; \
	chown stunnel4:stunnel4 /run/stunnel

# hadolint ignore=DL3013
RUN pipx install jinja2-cli

COPY --chmod=644 /rootfs/config /etc/rspamd/
COPY --chmod=644 /rootfs/stunnel.conf.j2 /etc/stunnel/
COPY --chmod=644 /rootfs/supervisord.conf /etc/supervisor/conf.d/

# 11332 (worker proxy - milter protocol)
EXPOSE 11332

VOLUME ["/etc/rspamd/arc/", "/etc/rspamd/dkim/", "/var/lib/rspamd/"]

COPY --chmod=755 /rootfs/docker-entrypoint.sh /

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD [ "/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf" ]

HEALTHCHECK \
	CMD rspamc uptime || exit 1
