# Fix Email Delivery — Port 25 Connection Timeout

## Context

The email delivery troubleshooter shows that TCP connection to `103.197.188.27:25` **times out**. MX lookup succeeds, IP resolves correctly, but no SMTP handshake happens. Meanwhile, port 443 (webmail) works fine through the same gateway → Tailscale → primary path. This means nginx and Tailscale are functional — the problem is specific to port 25.

## Diagnosis

The most likely cause is **Biznet Gio blocking inbound port 25** at the hypervisor/network level. Most VPS providers block SMTP ports by default to prevent spam abuse. UFW rules and nginx config are correct in the Ansible code, but a provider-level firewall sits outside our control.

We need to confirm this with live diagnostics before requesting a port unblock.

## Plan

### Step 1: Diagnose on gateway (remote commands)

SSH to gateway and run these checks:

```bash
# 1. Is nginx running and listening on port 25?
ss -tlnp | grep ':25'

# 2. UFW status — is port 25 allowed?
sudo ufw status verbose | grep 25

# 3. Can we reach primary:25 through Tailscale?
nc -zv 100.115.223.100 25 -w 5

# 4. Is the nginx stream module loaded?
nginx -T 2>&1 | grep -A2 'stream'
```

**Expected outcome:** nginx is listening on 25, UFW allows it, Tailscale tunnel works — confirming the block is at the Biznet Gio network layer.

### Step 2: Diagnose on primary

```bash
# Is Stalwart listening on port 25?
ss -tlnp | grep ':25'
```

### Step 3: Fix the port 25 block

Based on diagnosis:

- **If Biznet Gio is blocking** (most likely): Open a support ticket or use the Biznet Gio portal to request inbound port 25 be unblocked on the gateway VPS. This is a manual step — you'll need to justify the use case (self-hosted mail server).

- **If nginx isn't listening on 25**: The stream config may not be loading. Fix: move `stream.conf` from `/etc/nginx/modules-enabled/` to a top-level include, or add `include /etc/nginx/stream.conf;` to `/etc/nginx/nginx.conf` outside the `http {}` block.

- **If Tailscale can't reach primary:25**: Check that Stalwart is bound to `0.0.0.0:25` (not `127.0.0.1:25`) and that primary's firewall allows port 25 from the Tailscale subnet.

### Step 4: Verify the fix

After port 25 is unblocked, re-run the delivery test:

```bash
# From any external machine:
nc -zv 103.197.188.27 25 -w 5

# Or use the same troubleshooting tool that produced the screenshot
```

Should see a successful SMTP banner (`220 mail.wikaniagasukses.com`).

## Other delivery issues (not blocking inbound, but needed for full flow)

These are already tracked in the plan doc but are secondary to the port 25 fix:

1. **Mailgun domain registration** — outbound relay won't work until `mg.wikaniagasukses.com` is added to Mailgun
2. **DKIM DNS record** — extract public key from Stalwart web UI, add TXT record via `dns_setup.sh`
3. **Config template drift** — the live server has `http.url = "'https://mail.wikaniagasukses.com'"` but the Ansible template uses `server.listener.http.url` instead; sync the template

## Files involved

- `infra/roles/gateway/tasks/main.yml` — UFW rules, nginx config deployment
- `infra/roles/gateway/templates/nginx_stream.conf.j2` — stream proxy config
- `infra/roles/stalwart/templates/config.toml.j2` — Stalwart config (may need `http.url` fix)
- `infra/inventory.ini` — host details

## Verification

1. `nc -zv 103.197.188.27 25` returns SMTP banner
2. Re-run the email delivery troubleshooter — "Delivery attempt" step succeeds
3. Send test email from Gmail → `geraldi@wikaniagasukses.com` — arrives in Stalwart inbox
