# DKIM Key Rotation Guide

This guide covers best practices for rotating DKIM signing keys in the rspamd-worker container.

## Table of Contents

- [Overview](#overview)
- [When to Rotate](#when-to-rotate)
- [Impact Summary](#impact-summary)
- [Rotation Process](#rotation-process)
- [Emergency Rotation](#emergency-rotation)
- [Troubleshooting](#troubleshooting)

## Overview

DKIM (DomainKeys Identified Mail) keys should be rotated periodically to maintain security. Unlike ARC keys, DKIM signatures are validated long after delivery, so rotation requires careful planning.

### Key Facts

- **Recommended frequency**: Every 12-24 months
- **Grace period needed**: 30-90 days
- **Risk level**: Medium-High (affects historical mail validation)
- **DNS propagation**: 24-48 hours minimum

## When to Rotate

### Scheduled Rotation

Rotate DKIM keys:

- **Annually** (minimum recommended)
- **Every 6 months** (high-security environments)
- **After 2 years maximum** (avoid cryptographic weakness)

### Immediate Rotation Required

- Private key compromised or suspected breach
- Staff turnover (key holders leaving)
- System compromise or unauthorized access
- Compliance requirements

## Impact Summary

### What's Affected

| Component | Impact | Duration |
| ----------- | -------- | ---------- |
| **New outgoing mail** | ✅ Signed with new key | Immediate |
| **Historical mail** | ⚠️ Old signatures remain valid | Until removed |
| **Archived mail** | ❌ Breaks if old key removed early | Permanent |
| **Mail in transit** | ⚠️ May use either key | During grace period |
| **Reputation** | ⚠️ Brief dip possible | 1-7 days |

### Recipient Impact

- **Gmail/Yahoo/Outlook**: May temporarily flag as "new sender" if old key removed too soon
- **Corporate servers**: May cache DNS records longer (respect TTL)
- **Spam filters**: Brief learning period with new key
- **DMARC**: May report temporary alignment issues

## Rotation Process

### Step 1: Generate New Key

Generate a new DKIM key with a date-based selector:

```bash
# Current: dkim20260101
# New: dkim20260701 (July 2026 rotation)

docker exec rspamd-worker rspamadm dkim_keygen \
  -s dkim20260701 \
  -d domain1.com \
  -k /tmp/dkim20260701.key

docker cp rspamd-worker:/tmp/dkim20260701.key ./dkim20260701.key
```

**Recommended key sizes:**

- **RSA 2048-bit**: Standard, widely compatible
- **RSA 4096-bit**: More secure, larger DNS records
- **Ed25519**: Modern, compact, not universally supported yet

### Step 2: Publish New DNS Record

**IMPORTANT**: Keep old DNS record active!

```dns
; Old selector (keep active)
dkim20260101._domainkey.domain1.com. 300 IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."

; New selector (add alongside)
dkim20260701._domainkey.domain1.com. 300 IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."
```

**DNS TTL considerations:**

- Set TTL to **300 seconds (5 minutes)** during rotation
- Allows faster propagation and rollback if needed
- Increase to 3600+ after rotation completes

### Step 3: Verify DNS Propagation

Wait 24-48 hours, then verify:

```bash
# Check from multiple locations
dig +short dkim20260701._domainkey.domain1.com TXT

# Verify globally
nslookup -q=TXT dkim20260701._domainkey.domain1.com 8.8.8.8
nslookup -q=TXT dkim20260701._domainkey.domain1.com 1.1.1.1

# Test with online tools
# - https://mxtoolbox.com/dkim.aspx
# - https://dmarcian.com/dkim-inspector/
```

### Step 4: Deploy New Key to Container

Copy the new key to the container volume:

```bash
# Copy to volume location
cp dkim20260701.key /path/to/rspamd-worker/volumes/dkim/

# Or if using docker cp
docker cp dkim20260701.key rspamd-worker:/etc/rspamd/dkim/

# Set proper permissions
docker exec rspamd-worker chown _rspamd:_rspamd /etc/rspamd/dkim/dkim20260701.key
docker exec rspamd-worker chmod 600 /etc/rspamd/dkim/dkim20260701.key
```

### Step 5: Update Configuration

**Option A: Using default selector (all domains):**

```bash
# Update environment variable
RSPAMD_DKIM_DEFAULT_SELECTOR=dkim20260701

# Restart container
docker restart rspamd-worker
```

**Option B: Per-domain selectors:**

```bash
# Update selector map
RSPAMD_DKIM_DOMAINS_SELECTORS="
domain1.com dkim20260701
sub1.domain1.com dkim20260701
domain2.com dkim20260701
domain3.org dkim20260701
"

# Restart container
docker restart rspamd-worker
```

### Step 6: Verify Signing

Test that new selector is being used:

```bash
# Send test email
echo "Test DKIM rotation" | mail -s "DKIM Test" test@example.com

# Check rspamd logs
docker logs rspamd-worker | grep -i dkim

# Expected output:
# "signed message; selector=dkim20260701"
```text

**Verify received email headers:**

```text
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
    d=domain1.com; s=dkim20260701; t=1234567890;  <-- New selector
    h=from:to:subject:date;
    bh=...;
    b=...
```

### Step 7: Grace Period (30-90 Days)

**During grace period:**

- ✅ Keep both DNS records published
- ✅ Keep old private key in container (for reference)
- ✅ Monitor for any DKIM failures
- ✅ Both selectors remain valid

**Why the wait?**

- Mail in transit may still be signed with old key
- Archived/forwarded mail needs old key for verification
- Third-party services may have cached old key
- Gives users time to report issues

### Step 8: Remove Old Key

After 30-90 days:

```bash
# 1. Remove old DNS record
# Delete: dkim20260101._domainkey.domain1.com

# 2. Wait 7 days (one more week of cached DNS)

# 3. Remove old key file from container
docker exec rspamd-worker rm /etc/rspamd/dkim/dkim20260101.key
```

**Verification:**

```bash
# Old selector should now fail
dig +short dkim20260101._domainkey.domain1.com TXT
# (should return empty or NXDOMAIN)

# New selector should still work
dig +short dkim20260701._domainkey.domain1.com TXT
# (should return public key)
```

## Emergency Rotation

When private key is compromised, act quickly but carefully:

### Immediate Actions (Day 0)

1. **Generate new key immediately**

   ```bash
   docker exec rspamd-worker rspamadm dkim_keygen \
     -s dkim20260301emergency \
     -k /etc/rspamd/dkim/dkim20260301emergency.key
   ```

2. **Publish new DNS record immediately** (keep old)

3. **Update configuration** (no waiting)

   ```bash
   RSPAMD_DKIM_DEFAULT_SELECTOR=dkim20260301emergency
   docker restart rspamd-worker
   ```

### Short Grace Period (7-14 Days)

1. **Monitor closely** for issues

2. **Remove compromised key DNS** after 7-14 days
   - Shorter than normal grace period
   - Balance security vs. historical validation

### Communication

1. **Notify stakeholders**:
   - Email administrators
   - Update DMARC reports monitoring
   - Document incident

### Revocation

1. **Optional: Publish revocation notice**:

   ```dns
   dkim20260101._domainkey.domain1.com. IN TXT "v=DKIM1; p="
   ```

   Empty `p=` tag signals key revocation.

## Troubleshooting

### Issue: New signatures not appearing

**Check 1: Configuration loaded?**

```bash
docker exec rspamd-worker cat /etc/rspamd/dkim_selectors.map
# Should show new selector

docker logs rspamd-worker | grep -i selector
```

**Check 2: Key file exists and readable?**

```bash
docker exec rspamd-worker ls -la /etc/rspamd/dkim/
docker exec rspamd-worker test -r /etc/rspamd/dkim/dkim20260701.key && echo "OK" || echo "NOT READABLE"
```

**Check 3: Restart applied?**

```bash
docker restart rspamd-worker
docker logs rspamd-worker | tail -50
```

### Issue: DNS not propagating

**Check 1: DNS syntax correct?**

```bash
# TXT record must be quoted
# Long keys should be split: "part1" "part2"

dkim20260701._domainkey.domain1.com. IN TXT (
    "v=DKIM1; k=rsa; "
    "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."
)
```

**Check 2: DNS TTL expired?**

```bash
# Check TTL
dig dkim20260701._domainkey.domain1.com TXT +ttlid

# Wait: TTL seconds + 15 minutes buffer
```

**Check 3: Authoritative servers updated?**

```bash
# Query your nameservers directly
dig @ns1.yourdns.com dkim20260701._domainkey.domain1.com TXT
```

### Issue: DKIM failures reported

**Check 1: Header canonicalization issue?**

```bash
# Default is relaxed/relaxed, may need adjustment
# Check DMARC reports for alignment issues
```

**Check 2: Body hash mismatch?**

- Content modification by middleware
- Charset issues
- Line ending problems (CRLF vs LF)

**Check 3: Signature expiration?**

```bash
# Check signature timestamp in headers
# t= tag should be recent
```

### Issue: Reputation drop after rotation

**Expected**: Minor, temporary dip for 1-7 days

**Mitigation**:

- Maintain consistent sending patterns
- Keep old key active during grace period
- Monitor bounce rates and spam reports
- Gradually increase volume if needed

## Best Practices Summary

### ✅ DO

- Rotate every 12-24 months
- Use date-based selectors (e.g., `dkim20260701`)
- Maintain 30-90 day grace period
- Keep both DNS records during transition
- Test thoroughly before removal
- Document rotation schedule
- Monitor DMARC reports
- Use 2048-bit or stronger keys

### ❌ DON'T

- Remove old DNS record immediately
- Rotate multiple domains simultaneously (stagger them)
- Use generic selectors (e.g., `default`, `mail`)
- Skip DNS propagation verification
- Ignore DMARC alignment reports
- Rotate during high-traffic periods
- Store keys without encryption/protection

## Rotation Schedule Template

```text
DKIM Key Rotation Schedule

Current Key:
- Selector: dkim20260101
- Generated: 2026-01-01
- Next rotation: 2027-01-01

Rotation Timeline:
- T-30 days: Generate new key, publish DNS (both active)
- T-7 days: Verify DNS propagation globally
- T-0 (rotation day): Update configuration, restart services
- T+30 days: Monitor DMARC reports, check for issues
- T+60 days: Remove old DNS record if no issues
- T+67 days: Remove old key file from containers

Emergency Contact:
- Administrator: email@example.com
- Backup: backup@example.com
- Documentation: /path/to/runbook
```

## Additional Resources

- [RFC 6376 - DKIM Signatures](https://datatracker.ietf.org/doc/html/rfc6376)
- [Rspamd DKIM Signing Module](https://docs.rspamd.com/modules/dkim_signing)
- [DKIM Key Length Recommendations](https://datatracker.ietf.org/doc/html/rfc8301)
- [DMARC Reporting](https://dmarc.org)

## Maintenance Log

Keep a record of rotations:

```text
| Date       | Old Selector  | New Selector  | Notes                    |
|------------|---------------|---------------|--------------------------|
| 2026-01-01 | dkim20250701  | dkim20260101  | Yearly rotation          |
| 2026-07-01 | dkim20260101  | dkim20260701  | 6-month rotation (new)   |
| 2027-01-01 | dkim20260701  | dkim20270101  | Yearly rotation          |
```
