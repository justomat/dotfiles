# Fix inbound mail delivery to geraldi@wikaniagasukses.com

## Context

Mail sent from external senders (e.g. `sutantogeraldi@icloud.com`, Google bounces, etc.) to `geraldi@wikaniagasukses.com` is never landing in the mailbox. Every inbound message gets accepted at SMTP RCPT, queued, then silently discarded after a double-bounce. The geraldi IMAP mailbox is not receiving anything from outside the server.

## Root cause (confirmed from live logs)

Every inbound message follows this path in `journalctl -u stalwart-mail`:

1. `smtp.rcpt-to` accepted for `geraldi@wikaniagasukses.com` (principal + domain both exist).
2. `queue.queue-message` — queued as `queueName = "local"`, `domain = "wikaniagasukses.com"` (domain correctly flagged local).
3. `delivery.connect` — Stalwart nevertheless opens a connection to `mail.smtp2go.com:2525`.
4. `delivery.message-rejected` — smtp2go replies `550 From header sender domain not verified (icloud.com|google.com)`.
5. `delivery.dsn-perm-fail` → DSN queued → `delivery.double-bounce` → message discarded.

The recipient domain IS local, the principal IS configured with `email-receive`, but Stalwart still selects the `relay` route instead of the `local` route. The cause is `infra/roles/stalwart/templates/config.toml.j2:71`:

```toml
queue.strategy.route = "'relay'"
```

This is an unconditional expression — it evaluates to the literal string `"relay"` for every message, so EVERY queued message (including local-domain recipients) is handed to the smtp2go relay. Stalwart already has a built-in `local` route (verified via `GET /api/settings/list?prefix=queue.route` → `queue.route.local.type = "local"`) which would deliver straight to the IMAP mailbox — but it's never selected.

Verified state:
- `queue.route.local.type = local` ✓
- `queue.route.mx.type = mx` ✓
- `queue.route.relay.type = relay` ✓ (→ mail.smtp2go.com:2525)
- `queue.strategy.route = "'relay'"` ← BUG
- `wikaniagasukses.com` is a local domain (principal id=1, members=8)
- `geraldi` principal has `emails = [geraldi@wikaniagasukses.com, ...]` and `email-receive`
- Gateway port-25 NAT passthrough is healthy — real external mail (icloud, google) does arrive at Stalwart.
- My Mac's external `nc 103.197.188.27:25` timeout is a red herring — my residential ISP blocks outbound 25. Gateway + Tailscale + Stalwart inbound path works.

## Fix — one config line

Replace the unconditional relay strategy with one that routes local domains to the `local` route and everything else to the `relay` route.

**File**: `infra/roles/stalwart/templates/config.toml.j2` line 71.

Change:

```toml
# Route all outbound mail through smtp2go.
queue.strategy.route = "'relay'"
```

to:

```toml
# Local-domain recipients go to the local mailbox route; everything else goes
# out via smtp2go (port 25 egress is blocked on this VPS).
queue.strategy.route = "if is_local_domain('', rcpt_domain) { 'local' } else { 'relay' }"
```

Notes:
- `is_local_domain('', rcpt_domain)` — first arg is the directory name; `''` means Stalwart picks the default (`internal`).
- The expression-literal quoting rules in CLAUDE.md apply: the whole RHS is a single TOML string containing a Stalwart expression; `'local'` and `'relay'` are expression-language string literals.
- If Stalwart rejects `is_local_domain('', …)` at startup, the fallback syntax is `is_local_domain(rcpt_domain)` (older form). Parse errors surface in `journalctl -u stalwart-mail` at service start — watch for them on the deploy.

## Deploy

```bash
ansible-playbook -i infra/inventory.ini infra/primary.yml --tags stalwart
```

The stalwart role renders `/etc/stalwart/config.toml` from the template and restarts `stalwart-mail`. No gateway changes needed.

## Also flush the poisoned queue

After the deploy, two messages are still stuck (`302608802937661114`, `302608804814613178`) plus any new DSNs. They were queued under the broken strategy and will keep double-bouncing even with the fix because the queued envelopes still carry the bad route decision. Clear them via the admin API:

```bash
PASS=$(ansible-vault view infra/vars/secrets.yml 2>/dev/null | awk -F'"' '/stalwart_admin_password:/ {print $2}')
# or read /etc/stalwart/config.toml on primary if the playbook rendered it plaintext.
curl -u "admin:$PASS" -X DELETE "http://127.0.0.1:8080/api/queue/messages/<id>"
```

(Run on `dev@primary`. Admin password is currently `DOe7cyruMb` in `infra/vars/secrets.yml` — already known, no decryption needed.)

## Verification

1. **Service starts clean**
   ```bash
   ssh dev@primary 'systemctl is-active stalwart-mail; sudo journalctl -u stalwart-mail -n 50 --no-pager | grep -iE "error|expr|parse"'
   ```
   Expect `active` and no expression/parse errors.

2. **Local→local delivery (internal smoke test, proves the new route works)**
   Inject a message via SMTP submission from a known principal to `geraldi@wikaniagasukses.com` and confirm it's delivered to the mailbox, not relayed.
   ```bash
   ssh dev@primary 'swaks --to geraldi@wikaniagasukses.com --from ayu@wikaniagasukses.com \
     --server 127.0.0.1:587 --auth LOGIN --auth-user ayu --auth-password <ayu-pass> \
     --tls'
   # Then tail logs for this delivery
   sudo journalctl -u stalwart-mail -n 30 --no-pager | grep -E "queueId|deliver"
   ```
   Expect `delivery.attempt-start` → **no** `mail.smtp2go.com` connection → `delivery.completed` with elapsed < 1s. `queueName` should still read `local` but the delivery should not connect out anywhere.

3. **External→local delivery (golden-path receive test)**
   Send from a third-party mailbox (Gmail, iCloud) to `geraldi@wikaniagasukses.com`. Then, from local Mac, check IMAP using the built-in macOS `mail` CLI alternative — or use `swaks`/`openssl s_client` on 993 to verify:
   ```bash
   openssl s_client -connect 103.197.188.27:993 -crlf -quiet <<'EOF'
   a login geraldi <geraldi-pass>
   b select INBOX
   c search since 19-Apr-2026
   d logout
   EOF
   ```
   Expect at least one new UID in the search result referring to the test message.

   Alternatively: on primary, re-query the principal to see `usedQuota` increase and new message ID:
   ```bash
   curl -u admin:DOe7cyruMb http://127.0.0.1:8080/api/principal/geraldi | jq .usedQuota
   ```

4. **Outbound still relays via smtp2go**
   Send an email from `geraldi@wikaniagasukses.com` to an external address (e.g. your own gmail). Tail logs and confirm `hostname = "mail.smtp2go.com"` on the delivery attempt — the existing outbound path must not regress.

## Out of scope / follow-ups already noted in docs

These surfaced during investigation but are not needed to unblock inbound receive:
- DKIM signers `rsa-wikaniagasukses.com` / `ed25519-wikaniagasukses.com` don't exist (logs show `dkim.signer-not-found`). Impacts outbound reputation, not local delivery. Tracked in `docs/superpowers/retros/2026-04-12-stalwart-mail-setup.md`.
- `_25._tcp.mail.smtp2go.com` TLSA DNSSEC lookup returns "Bogus" — Stalwart continues (strict=false). Harmless.
- `stalwart_admin_password_hash` is referenced in `config.toml.j2:4` but not defined in `infra/vars/secrets.yml`. Must be supplied via `-e` or separate vars file when running the playbook, or the render fails. Separate hygiene issue.

## Critical files

- `infra/roles/stalwart/templates/config.toml.j2:71` — the one-line fix
- `infra/roles/stalwart/tasks/main.yml` — unchanged; already restarts the service on template change
- `infra/primary.yml` — deploy entry point
