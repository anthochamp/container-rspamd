# alpine 3.19.1 comes with rspamd 3.8.1
FROM alpine:3.19.1

# hadolint ignore=DL3018
RUN apk add --update --no-cache jinja2-cli rspamd rspamd-client

COPY --chmod=644 /rootfs/config /etc/rspamd/

# 11332 (worker proxy), 11334 (controller)
EXPOSE 11332 11334

VOLUME ["/etc/rspamd/dkim/", "/var/lib/rspamd/"]

COPY --chmod=755 /rootfs/docker-entrypoint.sh /

ENTRYPOINT ["./docker-entrypoint.sh"]

CMD [ "rspamd", "-f", "-u", "rspamd", "-g", "rspamd" ]

HEALTHCHECK \
	CMD rspamc uptime || exit 1
