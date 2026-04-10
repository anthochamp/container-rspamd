# Rspamd Container

![GitHub License](https://img.shields.io/github/license/anthochamp/container-rspamd?style=for-the-badge)
![GitHub Release](https://img.shields.io/github/v/release/anthochamp/container-rspamd?style=for-the-badge&color=457EC4)
![GitHub Release Date](https://img.shields.io/github/release-date/anthochamp/container-rspamd?style=for-the-badge&display_date=published_at&color=457EC4)

Container images based on [Rspamd](https://rspamd.com/), a fast, free, and open-source spam filtering system with support for DKIM/ARC signing, DMARC reporting, fuzzy hashing, Redis-backed learning, and milter-based Postfix integration.

## How to use this image

```shell
docker run -d \
  -p 11332:11332 \
  -p 11334:11334 \
  -v ./dkim:/etc/rspamd/dkim:ro \
  -v ./arc:/etc/rspamd/arc:ro \
  -v rspamd-data:/var/lib/rspamd \
  -e RSPAMD_REDIS_HOST=redis:6379 \
  -e RSPAMD_DNS_HOST=unbound:53 \
  -e RSPAMD_CONTROLLER_PASSWORD=your_hashed_password \
  anthochamp/rspamd
```

## Volumes

- `/etc/rspamd/dkim/` — DKIM signing keys (read-only). Map key files named `<selector>.key` per domain or use domain-specific selectors via `RSPAMD_DKIM_DOMAINS_SELECTORS`.
- `/etc/rspamd/arc/` — ARC signing keys (read-only). Same layout as DKIM keys.
- `/var/lib/rspamd/` — Rspamd state (fuzzy storage, statistics databases).

## Ports

| Port  | Protocol | Description                                    |
|-------|----------|------------------------------------------------|
| 11332 | TCP      | Milter protocol (Postfix integration)          |
| 11334 | TCP      | Controller WebUI and HTTP API                  |
| 11335 | TCP      | Fuzzy storage worker (internal, rarely exposed)|

## Worker architecture

This container runs a complete Rspamd installation:

- **Proxy workers** (4 instances, port 11332): Handle milter protocol and perform self-scanning.
- **Controller worker** (port 11334): Provides WebUI and HTTP API.
- **Fuzzy storage worker** (port 11335): Stores fuzzy hashes locally.
- **Normal worker**: Disabled (proxy workers handle scanning directly).

## Configuration

Sensitive values may be loaded from files by appending `__FILE` to any supported `RSPAMD_`-prefixed variable (e.g. `RSPAMD_CONTROLLER_PASSWORD__FILE=/run/secrets/rspamd_password`).

### Core

#### RSPAMD_LOG_LEVEL

**Default**: `notice`

Rspamd log level. See [Rspamd logging documentation](https://rspamd.com/doc/configuration/logging.html) for possible values.

#### RSPAMD_REDIS_HOST

**Default**: *empty*

Redis server address (`host:port`). Required for Bayes classification, neural network, reputation tracking, and greylist modules. Also enables URL redirector caching.

#### RSPAMD_DNS_HOST

**Default**: *empty*

Custom DNS resolver address (`host:port`).

### Controller

#### RSPAMD_CONTROLLER_PASSWORD

**Default**: *empty*

Password protecting the controller WebUI and HTTP API. Generate with:

```shell
docker run --rm rspamd/rspamd rspamadm pw
```

If unset, the controller is open to all clients (suitable only for isolated internal networks).

### DKIM signing

Key files must be placed in `/etc/rspamd/dkim/`. Refer to [Rspamd DKIM signing documentation](https://rspamd.com/doc/modules/dkim_signing.html) for key format.

#### RSPAMD_DKIM_DEFAULT_SELECTOR

**Default**: *empty*

Default DKIM selector used when no domain-specific selector is configured.

#### RSPAMD_DKIM_DOMAINS_SELECTORS

**Default**: *empty*

Domain-to-selector map in Rspamd map format. See [Rspamd documentation on using maps](https://rspamd.com/doc/modules/dkim_signing.html#using-maps) for syntax.

### ARC signing

Key files must be placed in `/etc/rspamd/arc/`. Refer to [Rspamd ARC documentation](https://rspamd.com/doc/modules/arc.html) for key format.

#### RSPAMD_ARC_DEFAULT_SELECTOR

**Default**: *empty*

Default ARC selector used when no domain-specific selector is configured.

#### RSPAMD_ARC_DOMAINS_SELECTORS

**Default**: *empty*

Domain-to-selector map in Rspamd map format. See [Rspamd documentation on using maps for ARC](https://rspamd.com/doc/modules/arc.html#using-maps-for-selectors-and-paths) for syntax.

#### RSPAMD_ARC_INBOUND_DOMAIN

**Default**: *empty*

Domain used to sign inbound messages with ARC (`use_domain_sign_inbound`). When set, Rspamd will apply ARC sealing to inbound mail using this domain.

### DMARC reporting

Generates and delivers daily aggregate [DMARC](https://www.rfc-editor.org/rfc/rfc7489) reports to domain owners. Requires Redis.

#### RSPAMD_DMARC_REPORTING_ENABLED

**Default**: `0`

Set to `1` to enable DMARC report generation and delivery.

#### RSPAMD_DMARC_REPORTING_FROM

**Default**: *empty*

Sender email address for DMARC reports (e.g. `dmarc-reports@example.com`).

#### RSPAMD_DMARC_REPORTING_ORG_NAME

**Default**: *empty*

Organization name included in DMARC reports.

#### RSPAMD_DMARC_REPORTING_DOMAIN

**Default**: *empty*

Domain name included in DMARC reports.

#### RSPAMD_DMARC_REPORTING_SMTP_HOST

**Default**: *empty*

SMTP server hostname for report delivery.

#### RSPAMD_DMARC_REPORTING_SMTP_PORT

**Default**: `587`

SMTP server port.

#### RSPAMD_DMARC_REPORTING_SMTP_USERNAME

**Default**: *empty*

SMTP authentication username.

#### RSPAMD_DMARC_REPORTING_SMTP_PASSWORD

**Default**: *empty*

SMTP authentication password.

#### RSPAMD_DMARC_REPORTING_SMTP_TLS

**Default**: `starttls`

SMTP TLS mode:

| Value      | Description                              |
|------------|------------------------------------------|
| `none`     | No TLS (port 25)                         |
| `starttls` | STARTTLS upgrade (port 587, recommended) |
| `smtps`    | Implicit TLS (port 465)                  |

### Fuzzy storage

Perceptual hashing database for collaborative spam detection. The container includes a built-in fuzzy storage worker on port 11335.

#### RSPAMD_FUZZY_STORAGE_KEY

**Default**: *empty*

Encryption key for the local fuzzy storage. Generate with `rspamadm keypair`.

#### RSPAMD_FUZZY_UPSTREAM_ENABLED

**Default**: `0`

Set to `1` to also query rspamd.com public fuzzy feeds (read-only). Adds symbols `FUZZY_RSPAMD_COM`, `FUZZY_RSPAMD_COM_BLOCKED`, and `FUZZY_RSPAMD_COM_WHITE`.

### URL redirector

Follows shortened URLs (bit.ly, etc.) to check the final destination against reputation lists and blacklists. Requires Redis for result caching.

#### RSPAMD_URL_REDIRECTOR_ENABLED

**Default**: `0`

Set to `1` to enable the URL redirector module.

#### RSPAMD_URL_REDIRECTOR_MAX_REDIRECTS

**Default**: `5`

Maximum number of HTTP redirects to follow per URL.

#### RSPAMD_URL_REDIRECTOR_TIMEOUT

**Default**: `10`

Timeout in seconds per redirect request.

#### RSPAMD_URL_REDIRECTOR_NESTED_LIMIT

**Default**: `5`

Number of parallel URL resolution workers.

## Dovecot learning integration

When paired with the Dovecot container, users train the spam filter by moving messages in or out of the Junk folder:

1. User moves email to Junk → Dovecot Sieve triggers `learn-spam.sh` → `rspamc learn_spam` + `rspamc fuzzy_add`.
2. User moves email from Junk → Dovecot Sieve triggers `learn-ham.sh` → `rspamc learn_ham` + `rspamc fuzzy_del`.

Configure the corresponding Dovecot variables:

```yaml
DOVECOT_RSPAMD_HOST: rspamd
DOVECOT_RSPAMD_PORT: 11332
DOVECOT_RSPAMD_FUZZY_WHITE_TAG: "2"   # Ham flag
DOVECOT_RSPAMD_FUZZY_DENIED_TAG: "1"  # Spam flag
```

## Example Docker Compose

```yaml
services:
  rspamd:
    image: anthochamp/rspamd
    ports:
      - "11332:11332"
      - "11334:11334"
    volumes:
      - ./dkim:/etc/rspamd/dkim:ro
      - ./arc:/etc/rspamd/arc:ro
      - rspamd-data:/var/lib/rspamd
    environment:
      RSPAMD_LOG_LEVEL: notice
      RSPAMD_REDIS_HOST: redis:6379
      RSPAMD_DNS_HOST: unbound:53
      RSPAMD_CONTROLLER_PASSWORD: your_hashed_password
      RSPAMD_FUZZY_STORAGE_KEY: your_encryption_key
      RSPAMD_DKIM_DEFAULT_SELECTOR: mail
      RSPAMD_ARC_DEFAULT_SELECTOR: mail
      RSPAMD_DMARC_REPORTING_ENABLED: "1"
      RSPAMD_DMARC_REPORTING_FROM: dmarc-reports@example.com
      RSPAMD_DMARC_REPORTING_SMTP_HOST: postfix
      RSPAMD_DMARC_REPORTING_SMTP_PORT: "587"

volumes:
  rspamd-data:
```

Postfix integration:

```yaml
POSTFIX_MILTER_HOST: rspamd
POSTFIX_MILTER_PORT: "11332"
```

## References

- [Rspamd documentation](https://rspamd.com/doc/)
- [DKIM signing module](https://rspamd.com/doc/modules/dkim_signing.html)
- [ARC module](https://rspamd.com/doc/modules/arc.html)
- [Neural network module](https://rspamd.com/doc/modules/neural.html)
- [Reputation module](https://rspamd.com/doc/modules/reputation.html)
- [DMARC module](https://rspamd.com/doc/modules/dmarc.html)
- [URL list module](https://rspamd.com/doc/modules/url_redirector.html)
