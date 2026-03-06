# ARC Key Rotation Guide

This guide covers best practices for rotating ARC (Authenticated Received Chain) signing keys in the rspamd-worker container.

## Table of Contents

- [Overview](#overview)
- [When to Rotate](#when-to-rotate)
- [Impact Summary](#impact-summary)
- [Rotation Process](#rotation-process)
- [Emergency Rotation](#emergency-rotation)
- [Troubleshooting](#troubleshooting)

## Overview

ARC keys are used to preserve email authentication results when forwarding messages. Since ARC signatures are only validated during active forwarding (not on archived mail), rotation is simpler and lower-risk than DKIM rotation.

### Key Facts

- **Recommended frequency**: Every 6-12 months
- **Grace period needed**: 7-30 days (shorter than DKIM)
- **Risk level**: Low (affects only in-transit forwarding)
- **DNS propagation**: 24-48 hours minimum
- **Validation lifetime**: Minutes to hours (not years like DKIM)

### ARC vs DKIM Rotation

| Aspect | ARC | DKIM |
| -------- | ----- | ------ |
| **Rotation frequency** | 6-12 months | 12-24 months |
| **Grace period** | 7-30 days | 30-90 days |
| **Historical impact** | Low | High |
| **Risk level** | Low | Medium-High |
| **Validation scope** | Active forwarding | Archived + forwarded mail |

## When to Rotate

### Scheduled Rotation

Rotate ARC keys:

- **Every 6 months** (recommended for high-security)
- **Every 12 months** (minimum recommended)
- **Stagger with DKIM** (e.g., DKIM in January, ARC in July)

### Immediate Rotation Required

- Private key compromised or suspected breach
- Staff turnover (key holders leaving)
- System compromise
- Compliance requirements
- **Faster response than DKIM** (lower impact)

## Impact Summary

### What's Affected

| Component | Impact | Duration |
| ----------- | -------- | ---------- |
| **New forwarded mail** | ✅ Sealed with new key | Immediate |
| **Historical mail** | ✅ No impact (already delivered) | N/A |
| **In-flight forwards** | ⚠️ Brief validation gap | Minutes-hours |
| **Delivered mail** | ✅ ARC headers are historical only | No impact |
| **Reputation** | ✅ Minimal impact | None |

### Why Low Impact?

1. **Forward-only validation**: ARC only matters during forwarding, not after delivery
2. **Short validation window**: Messages validated within minutes, not archived for years
3. **No reputation**: ARC doesn't affect sender reputation like DKIM
4. **Fast propagation**: Shorter grace period acceptable

### Recipient Impact

- **Active forwarding**: May briefly fail validation during DNS propagation
- **Delivered mail**: No impact (ARC headers already present)
- **Spam filters**: Minimal impact (ARC is trust signal, not authentication)

## Rotation Process

### Step 1: Generate New Key

Generate a new ARC key with a date-based selector:

```bash
# Current: arc20260101
# New: arc20260701 (July 2026 rotation)

docker exec rspamd-worker rspamadm dkim_keygen \
  -s arc20260701 \
  -d domain1.com \
  -k /tmp/arc20260701.key

docker cp rspamd-worker:/tmp/arc20260701.key ./arc20260701.key
```

**Key type recommendation:**

- **RSA 2048-bit**: Standard, widely compatible (recommended)
- **Ed25519**: Modern, compact (check receiver support)

**Selector naming:**

- Use `arc` prefix: `arc20260701`
- Date-based: `arcYYYYMMDD`
- Distinct from DKIM: `arc*` vs `dkim*`

### Step 2: Publish New DNS Record

**IMPORTANT**: Keep old DNS record active during grace period!

```dns
; Old selector (keep active during grace period)
arc20260101._domainkey.domain1.com. 300 IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."

; New selector (add alongside)
arc20260701._domainkey.domain1.com. 300 IN TXT "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."
```

**Note**: ARC uses same DNS format as DKIM (`_domainkey` subdomain)

**DNS TTL:**

- **300 seconds (5 minutes)**: During rotation
- **3600 seconds (1 hour)**: Post-rotation
- Lower TTL = faster propagation and rollback

### Step 3: Verify DNS Propagation

Wait 24-48 hours minimum:

```bash
# Check DNS propagation
dig +short arc20260701._domainkey.domain1.com TXT

# Verify from multiple resolvers
dig @8.8.8.8 arc20260701._domainkey.domain1.com TXT
dig @1.1.1.1 arc20260701._domainkey.domain1.com TXT

# Check globally
nslookup -q=TXT arc20260701._domainkey.domain1.com 8.8.8.8
```

**Verification checklist:**

- ✅ Record visible from Google DNS (8.8.8.8)
- ✅ Record visible from Cloudflare DNS (1.1.1.1)
- ✅ Record visible from your authoritative nameservers
- ✅ Public key matches generated key

### Step 4: Deploy New Key to Container

Copy the new key to the container volume:

```bash
# Method 1: Copy to mounted volume
cp arc20260701.key /path/to/rspamd-worker/volumes/arc/

# Method 2: Docker cp
docker cp arc20260701.key rspamd-worker:/etc/rspamd/arc/

# Set proper permissions
docker exec rspamd-worker chown _rspamd:_rspamd /etc/rspamd/arc/arc20260701.key
docker exec rspamd-worker chmod 600 /etc/rspamd/arc/arc20260701.key

# Verify
docker exec rspamd-worker ls -la /etc/rspamd/arc/
```

### Step 5: Update Configuration

**Option A: Using default selector (all domains):**

```bash
# Update environment variable
RSPAMD_ARC_DEFAULT_SELECTOR=arc20260701

# Restart container
docker restart rspamd-worker
```

**Option B: Per-domain selectors:**

```bash
# Update selector map
RSPAMD_ARC_DOMAINS_SELECTORS="
domain1.com arc20260701
sub1.domain1.com arc20260701
domain2.com arc20260701
domain3.org arc20260701
"

# Restart container
docker restart rspamd-worker
```

**Docker Compose example:**

```yaml
services:
  rspamd-worker:
    environment:
      - RSPAMD_ARC_DEFAULT_SELECTOR=arc20260701
      - RSPAMD_ARC_DOMAINS_SELECTORS=domain1.com arc20260701
    volumes:
      - ./arc-keys:/etc/rspamd/arc:ro
```

### Step 6: Verify ARC Signing

Test that new selector is being used:

```bash
# Send test email through forwarding path
# (ARC only activates during forwarding)

# Check rspamd logs
docker logs rspamd-worker | grep -i arc

# Expected output:
# "arc sealed; i=1; d=domain1.com; s=arc20260701"
```text

**Verify in forwarded email headers:**

```text
ARC-Seal: i=1; a=rsa-sha256; d=domain1.com; s=arc20260701; t=1234567890;  <-- New selector
    cv=none;
    b=...

ARC-Message-Signature: i=1; a=rsa-sha256; d=domain1.com; s=arc20260701;
    h=from:to:subject:date:message-id;
    bh=...;
    b=...

ARC-Authentication-Results: i=1; domain1.com;
    dkim=pass header.d=example.com header.s=selector;
    spf=pass smtp.mailfrom=user@example.com;
```

### Step 7: Grace Period (7-30 Days)

**During grace period:**

- ✅ Keep both DNS records published
- ✅ Keep old private key in container
- ✅ Monitor for ARC validation failures
- ✅ Both selectors remain valid

**Why shorter than DKIM?**

- ARC validated only during active forwarding
- Messages delivered within hours, not archived for years
- Lower risk from historical validation issues
- Faster iteration possible

**Monitoring:**

```bash
# Watch for ARC signing errors
docker logs -f rspamd-worker | grep -i "arc.*error"

# Check mail logs for delivery issues
docker logs postfix | grep -i "arc\|forward"

# Review DMARC reports for alignment (optional)
```

### Step 8: Remove Old Key

After 7-30 days (typically 14 days):

```bash
# 1. Remove old DNS record
# Delete: arc20260101._domainkey.domain1.com TXT

# 2. Wait 7 days (cached DNS to expire)

# 3. Remove old key file from container
docker exec rspamd-worker rm /etc/rspamd/arc/arc20260101.key

# 4. Verify old selector no longer works
dig +short arc20260101._domainkey.domain1.com TXT
# (should return empty or NXDOMAIN)
```

**Post-removal verification:**

```bash
# New selector still works
dig +short arc20260701._domainkey.domain1.com TXT

# Container only has new key
docker exec rspamd-worker ls /etc/rspamd/arc/
# arc20260701.key
```

## Emergency Rotation

When ARC private key is compromised:

### Immediate Actions (Day 0)

1. **Generate new key immediately**

   ```bash
   # Use emergency naming
   docker exec rspamd-worker rspamadm dkim_keygen \
     -s arc20260301emergency \
     -k /etc/rspamd/arc/arc20260301emergency.key
   ```

2. **Publish new DNS record immediately**

   ```dns
   arc20260301emergency._domainkey.domain1.com. IN TXT "v=DKIM1; k=rsa; p=..."
   ```

3. **Update configuration immediately** (no waiting)

   ```bash
   RSPAMD_ARC_DEFAULT_SELECTOR=arc20260301emergency
   docker restart rspamd-worker
   ```

### Short Grace Period (3-7 Days)

1. **Monitor for issues**
   - Check forwarding functionality
   - Verify ARC chain validation
   - Watch bounce rates

2. **Remove compromised key** after 3-7 days

   ```bash
   # Shorter grace period than normal
   # ARC impact is minimal
   ```

### Revocation (Optional)

1. **Publish revocation**:

   ```dns
   # Empty p= signals revocation
   arc20260101._domainkey.domain1.com. IN TXT "v=DKIM1; p="
   ```

**Why faster than DKIM?**

- ARC doesn't affect archived mail
- Lower impact on reputation
- Only forwarding affected (brief window)
- Compromise risk outweighs disruption risk

## Troubleshooting

### Issue: New ARC seals not appearing

**Check 1: Configuration loaded?**

```bash
docker exec rspamd-worker cat /etc/rspamd/arc_selectors.map
# Should show new selector

docker exec rspamd-worker cat /etc/rspamd/local.d/arc.conf
# Should reference new selector
```

**Check 2: Key file exists and readable?**

```bash
docker exec rspamd-worker ls -la /etc/rspamd/arc/
docker exec rspamd-worker test -r /etc/rspamd/arc/arc20260701.key && echo "OK" || echo "NOT READABLE"
```

**Check 3: Restart applied?**

```bash
docker restart rspamd-worker
docker logs rspamd-worker | grep -E "arc|selector" | tail -20
```

**Check 4: Mail is being forwarded?**

```bash
# ARC only activates on forwarded mail
# Test with actual forwarding scenario
# Check: sign_local = true; sign_authenticated = true;
```

### Issue: DNS not propagating

**Check 1: Correct DNS format?**

```bash
# Must use _domainkey subdomain like DKIM
arc20260701._domainkey.domain1.com.
# NOT: arc20260701.domain1.com

# Must include v=DKIM1 (same format as DKIM)
"v=DKIM1; k=rsa; p=..."
```

**Check 2: TTL expired?**

```bash
dig arc20260701._domainkey.domain1.com TXT +ttlid
# Wait: (TTL value in seconds) + buffer
```

**Check 3: Authoritative servers updated?**

```bash
# Query your nameservers
dig @ns1.yourdns.com arc20260701._domainkey.domain1.com TXT
```

### Issue: ARC validation failing

**Check 1: ARC chain broken?**

```bash
# Each hop must preserve previous ARC sets
# i=1, i=2, i=3 (incrementing)
# cv= values must be valid (none, pass, fail)
```

**Check 2: Signature mismatch?**

```bash
# Check ARC-Message-Signature headers match
# Check ARC-Seal chain intact
docker logs rspamd-worker | grep -i "arc.*invalid"
```

**Check 3: Clock skew?**

```bash
# t= timestamp should be recent
# Check container clock
docker exec rspamd-worker date
```

### Issue: Old and new keys both signing

This is **expected during grace period**!

```bash
# Some messages may have mixed selectors
# Old: Still valid for in-flight messages
# New: Used for new messages

# Not a problem, both should work
# Remove old key only after grace period
```

## Best Practices Summary

### ✅ DO

- Rotate every 6-12 months
- Use `arc` prefix for selectors (e.g., `arc20260701`)
- Maintain 7-30 day grace period
- Keep both DNS records during transition
- Test with actual forwarding scenarios
- Use same key size as DKIM (2048-bit)
- Stagger rotation with DKIM (different months)
- Monitor forwarding functionality

### ❌ DON'T

- Use same key as DKIM (keep separate)
- Remove old DNS immediately
- Rotate during critical forwarding periods
- Use generic selectors (e.g., `default`, `mail`)
- Skip DNS verification
- Rotate ARC and DKIM simultaneously
- Ignore forwarding test results

## Rotation Schedule Template

```text
ARC Key Rotation Schedule

Current Key:
- Selector: arc20260101
- Generated: 2026-01-01
- Next rotation: 2026-07-01 (6 months)

Rotation Timeline:
- T-14 days: Generate new key, publish DNS (both active)
- T-7 days: Verify DNS propagation globally
- T-0 (rotation day): Update configuration, restart services
- T+7 days: Monitor forwarding, check for issues
- T+14 days: Remove old DNS record if no issues
- T+21 days: Remove old key file from containers

Notes:
- Staggered with DKIM (DKIM in January, ARC in July)
- Shorter grace period than DKIM (7-30 days vs 30-90 days)
- Lower risk rotation
```

## Coordination with DKIM

### Separate Keys, Separate Schedules

**Recommended approach:**

```text
January 2026:  DKIM rotation (selector: dkim20260101)
July 2026:     ARC rotation  (selector: arc20260701)
January 2027:  DKIM rotation (selector: dkim20270101)
July 2027:     ARC rotation  (selector: arc20270701)
```

**Benefits:**

- Staggered rotations reduce risk
- Easier troubleshooting (one at a time)
- Different grace periods don't overlap
- Clear separation of concerns

### Emergency Scenario

If both compromised:

1. Rotate DKIM first (higher risk)
2. Wait 24 hours
3. Rotate ARC (lower risk)
4. Monitor both closely

## Verification Checklist

Before removing old key, verify:

- [ ] New DNS record published and propagated
- [ ] New key deployed to all rspamd-worker instances
- [ ] Configuration updated with new selector
- [ ] Containers restarted
- [ ] New selector appearing in logs
- [ ] Test forwarding working with new key
- [ ] Grace period elapsed (minimum 7 days)
- [ ] No ARC validation errors in logs
- [ ] Mail flow functioning normally

## Additional Resources

- [RFC 8617 - ARC Protocol](https://datatracker.ietf.org/doc/html/rfc8617)
- [Rspamd ARC Module](https://docs.rspamd.com/modules/arc)
- [ARC vs DKIM Comparison](https://dmarc.org/wiki/FAQ#What_is_ARC.3F)

## Maintenance Log

Keep a record of rotations:

```text
| Date       | Old Selector | New Selector | Grace Period | Notes              |
|------------|--------------|--------------|--------------|---------------------|
| 2026-01-01 | arc20250701  | arc20260101  | 14 days      | 6-month rotation    |
| 2026-07-01 | arc20260101  | arc20260701  | 14 days      | 6-month rotation    |
| 2027-01-01 | arc20260701  | arc20270101  | 14 days      | 6-month rotation    |
```

## Key Differences from DKIM

Remember these distinctions when rotating ARC:

| Factor | ARC | DKIM |
| -------- | ----- | ------ |
| **Purpose** | Trust forwarding chain | Verify original sender |
| **Validation** | During forwarding only | Throughout mail lifetime |
| **Grace period** | 7-30 days | 30-90 days |
| **Risk** | Low | Medium-High |
| **Frequency** | 6-12 months | 12-24 months |
| **Emergency rotation** | Fast (3-7 days) | Slower (7-14 days) |
| **Impact on archives** | None | High |
| **Reputation** | Minimal | Significant |

**Bottom line**: ARC rotation is simpler, faster, and lower-risk than DKIM rotation.
