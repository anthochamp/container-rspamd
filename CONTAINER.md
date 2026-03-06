# Rspamd Container

## Environment variables

### Core Configuration

RSPAMD_LOG_LEVEL (default: notice)

RSPAMD_REDIS_HOST
RSPAMD_DNS_HOST

### Controller Configuration

RSPAMD_CONTROLLER_PASSWORD (optional - secures WebUI/API access, generated with `rspamadm pw`)

### Fuzzy Storage Configuration

RSPAMD_FUZZY_STORAGE_KEY (optional - encryption key for internal fuzzy storage)

RSPAMD_FUZZY_UPSTREAM_ENABLED (default: 0, set to 1 to enable rspamd.com upstream fuzzy feeds)

### DKIM/ARC Signing

RSPAMD_DKIM_DEFAULT_SELECTOR (uses keys from /etc/rspamd/dkim/)
RSPAMD_DKIM_DOMAINS_SELECTORS (uses keys from /etc/rspamd/dkim/) (cf. <https://docs.rspamd.com/modules/dkim_signing#using-maps>)

RSPAMD_ARC_DEFAULT_SELECTOR (uses keys from /etc/rspamd/arc/)
RSPAMD_ARC_DOMAINS_SELECTORS (uses keys from /etc/rspamd/arc/) (cf. <https://docs.rspamd.com/modules/arc#using-maps-for-selectors-and-paths>)

RSPAMD_ARC_INBOUND_DOMAIN

**Key Rotation Guides:**

- [DKIM Key Rotation Guide](DKIM-KEY-ROTATION.md) - Comprehensive guide for rotating DKIM signing keys
- [ARC Key Rotation Guide](ARC-KEY-ROTATION.md) - Comprehensive guide for rotating ARC signing keys

### DMARC Reporting Configuration

RSPAMD_DMARC_REPORTING_ENABLED (default: 0, set to 1 to enable)
RSPAMD_DMARC_REPORTING_FROM (sender email address for reports)
RSPAMD_DMARC_REPORTING_ORG_NAME (optional, organization name in reports)
RSPAMD_DMARC_REPORTING_DOMAIN (optional, domain name in reports)
RSPAMD_DMARC_REPORTING_SMTP_HOST (SMTP server hostname)
RSPAMD_DMARC_REPORTING_SMTP_PORT (default: 587)
RSPAMD_DMARC_REPORTING_SMTP_USERNAME (optional, for SMTP auth)
RSPAMD_DMARC_REPORTING_SMTP_PASSWORD (optional, for SMTP auth)
RSPAMD_DMARC_REPORTING_SMTP_TLS (default: starttls, options: none, starttls, smtps)

### URL Redirector Configuration

RSPAMD_URL_REDIRECTOR_ENABLED (default: 0, set to 1 to enable)
RSPAMD_URL_REDIRECTOR_MAX_REDIRECTS (default: 5)
RSPAMD_URL_REDIRECTOR_TIMEOUT (default: 10 seconds)
RSPAMD_URL_REDIRECTOR_NESTED_LIMIT (default: 5 parallel workers)

## Features

### Worker Architecture

This container runs a complete rspamd installation with all workers:

- **Proxy workers** (4 instances, port 11332): Handle milter protocol from Postfix and perform self-scanning
- **Controller worker** (1 instance, port 11334): Provides WebUI and HTTP API for administration
- **Fuzzy storage worker** (1 instance, port 11335): Stores fuzzy hashes for collaborative spam detection
- **Normal worker**: Disabled (proxy does self-scanning)

### Integration

This unified container provides:

- **Postfix integration**: Via milter protocol on port 11332
- **Web administration**: Controller WebUI on port 11334
- **Fuzzy storage**: Internal fuzzy hash database on port 11335
- **Redis**: For Bayes, greylist, neural, reputation, history
- **Dovecot**: Learning integration via rspamc commands

### Security

Set `RSPAMD_CONTROLLER_PASSWORD` to secure the WebUI and API. Generate with:

```bash
docker run --rm rspamd/rspamd:3.14.3 rspamadm pw
```

If not set, controller is open to all IPs (insecure but convenient for internal networks).

### Neural Module

Automatically enabled when Redis is configured. Uses machine learning to improve spam detection.

**Backend**: Requires Redis (`RSPAMD_REDIS_HOST`)
**Storage**: ~10-50MB in Redis with automatic expiration
**Learning**: Short-term (7d) and long-term (90d) networks train on messages ≥6 (spam) or ≤-2 (ham)
**Impact**: Adds symbols `NEURAL_SPAM_SHORT/LONG`, `NEURAL_HAM_SHORT/LONG`

### Reputation Module

Tracks sender reputation over time. Automatically enabled when Redis is configured.

**Backend**: Requires Redis
**Storage**: ~5-20MB in Redis, 30-day retention
**Tracking**: IP (10+ msgs), Domain (5+ msgs), SPF/DKIM reputation
**Impact**: Adds symbols `IP_REPUTATION`, `SENDER_DOMAIN_REPUTATION`, `SPF_REPUTATION`, `DKIM_REPUTATION`

### DMARC Reporting

Generates and sends daily aggregate DMARC reports to domain owners.

**Configuration**:

- Set `RSPAMD_DMARC_REPORTING_ENABLED=1`
- Configure sender email (`RSPAMD_DMARC_REPORTING_FROM`)
- Configure SMTP server details

**TLS Support**:

- `none`: Plain SMTP (port 25)
- `starttls`: STARTTLS (port 587) - default
- `smtps`: Implicit TLS/SSL (port 465)

**Example**:

```bash
RSPAMD_DMARC_REPORTING_ENABLED=1
RSPAMD_DMARC_REPORTING_FROM=dmarc-reports@example.com
RSPAMD_DMARC_REPORTING_ORG_NAME="Example Corp"
RSPAMD_DMARC_REPORTING_DOMAIN=example.com
RSPAMD_DMARC_REPORTING_SMTP_HOST=postfix
RSPAMD_DMARC_REPORTING_SMTP_PORT=587
RSPAMD_DMARC_REPORTING_SMTP_USERNAME=reports@example.com
RSPAMD_DMARC_REPORTING_SMTP_PASSWORD=secret
RSPAMD_DMARC_REPORTING_SMTP_TLS=starttls
```

### Fuzzy Storage

Distributed spam signature database using perceptual hashing for collaborative spam detection.

**Internal Fuzzy Storage**:
This container includes a built-in fuzzy storage worker (port 11335) for storing fuzzy hashes.

**Configuration**:

```bash
# Set encryption key for fuzzy storage
RSPAMD_FUZZY_STORAGE_KEY=your_encryption_key_here

# Enable Redis backend for persistence
RSPAMD_REDIS_HOST=redis:6379

# Optional: Enable rspamd.com upstream fuzzy feeds (public collaborative database)
RSPAMD_FUZZY_UPSTREAM_ENABLED=1
```

**Upstream Fuzzy Feeds**:

When `RSPAMD_FUZZY_UPSTREAM_ENABLED=1`, enables rspamd.com public fuzzy feeds:

- **Read-only access** to collaborative spam database
- Adds symbols: `FUZZY_RSPAMD_COM`, `FUZZY_RSPAMD_COM_BLOCKED`, `FUZZY_RSPAMD_COM_WHITE`
- Cannot learn to upstream (use your own fuzzy storage for learning)
- Complements your private fuzzy storage

**Dovecot Integration**:
The fuzzy storage integrates with the Dovecot container's learning scripts. When users move messages to/from Junk folder:

1. Dovecot triggers Sieve script (imapsieve)
2. Calls `learn-spam.sh` or `learn-ham.sh`  
3. Scripts execute:
   - `rspamc learn_spam/learn_ham` (Bayes learning)
   - `rspamc fuzzy_add/fuzzy_del` (Fuzzy storage learning)

**Environment variables in Dovecot**:

- `DOVECOT_RSPAMD_FUZZY_WHITE_TAG`: Tag for ham (flag 2)
- `DOVECOT_RSPAMD_FUZZY_DENIED_TAG`: Tag for spam (flag 1)

**How it works**:

- Fuzzy hashes detect exact/near-exact spam copies (content-based)
- Complements Bayes (word patterns) for comprehensive detection
- Internal fuzzy storage on port 11335 stores hashes locally
- Dovecot learning scripts update both Bayes and fuzzy storage

### Ports

This container exposes the following ports:

- **11332**: Milter protocol (for Postfix integration)
- **11334**: Controller WebUI/API (for administration)
- **11335**: Fuzzy storage (local worker, not typically exposed externally)

### URL Redirector

Follows shortened URLs (bit.ly, tinyurl, etc.) to check final destinations for phishing/malicious content.

**Configuration**:

```bash
RSPAMD_URL_REDIRECTOR_ENABLED=1
RSPAMD_URL_REDIRECTOR_MAX_REDIRECTS=5
RSPAMD_URL_REDIRECTOR_TIMEOUT=10
```

**Features**:

- Follows HTTP redirects up to max depth
- Checks final URL against blacklists
- Caches results in Redis (if configured)
- Detects phishing hidden behind shorteners

**Impact**: Small performance overhead for URLs that need resolution

## Dovecot Learning Integration

The container is designed to work with the Dovecot container's user-triggered learning:

1. User moves email to Junk folder
2. Dovecot Sieve script executes
3. Calls rspamd via `rspamc`:
   - `learn_spam`: Updates Bayes classifier
   - `fuzzy_add`: Adds to internal fuzzy storage

4. User moves email FROM Junk folder
5. Dovecot Sieve script executes
6. Calls rspamd via `rspamc`:
   - `learn_ham`: Updates Bayes classifier
   - `fuzzy_del`: Removes from internal fuzzy storage

This creates a feedback loop where users train the spam filter simply by moving messages.

**Configuration in Dovecot**:

```bash
# In dovecot container
DOVECOT_RSPAMD_HOST=rspamd
DOVECOT_RSPAMD_PORT=11332

# Fuzzy storage flags for learning
DOVECOT_RSPAMD_FUZZY_WHITE_TAG=2  # Ham flag
DOVECOT_RSPAMD_FUZZY_DENIED_TAG=1  # Spam flag
```

## Example Configuration

**Docker Compose**:

```yaml
services:
  rspamd:
    image: your-rspamd-image
    ports:
      - "11332:11332"  # Milter for Postfix
      - "11334:11334"  # WebUI/API
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
      # ... other config ...

volumes:
  rspamd-data:
```

**Postfix Integration**:

```bash
# In postfix container
POSTFIX_MILTER_HOST=rspamd
POSTFIX_MILTER_PORT=11332
```

**Access WebUI**:

Navigate to `http://your-server:11334` and login with your configured password.
