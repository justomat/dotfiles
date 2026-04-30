# Plan — Lock Stalwart Submission to `@wikaniagasukses.com` and Clean Up smtp2go Unverified Senders

## Context

smtp2go's "Verified Senders" dashboard is now showing four entries with a 100% rejection rate because their From: addresses are on domains we do not own and cannot DNS-verify:

- `ticket@smtp2go.com`
- `nochtaricardas@gmail.com`
- `e2eprefix1@example.org`
- `sutantogeraldi@icloud.com`

Root cause: `infra/roles/stalwart/templates/config.toml.j2` has no restriction on the envelope sender or `From:` header for authenticated submissions. Any authed user can submit mail with any `From:` address, Stalwart relays it to smtp2go, and smtp2go rejects everything that isn't on a verified sender domain — wasting relay attempts and polluting the dashboard.

Desired outcome (already aligned with user):

1. Authenticated SMTP submissions may use any address on `wikaniagasukses.com` in both the envelope sender (`MAIL FROM`) and the message `From:` header.
2. Anything else is hard-rejected at SMTP time (550) so it never reaches smtp2go.
3. The four unverified entries in the smtp2go dashboard are removed.

Out of scope: inbound SMTP on port 25 (accepts any `From:` by design), system-generated Stalwart mail (DMARC aggregate reports, bounces), and individual per-address smtp2go verification for foreign domains (user has explicitly chosen lockdown over per-address verification).

## Approach

Add two guarded Sieve scripts to the Stalwart config, one at the `MAIL` stage (envelope-from) and one at the `DATA` stage (From: header). Both guard on `${env.authenticated_as}` so the rules only apply to authenticated submissions on ports 465/587 — inbound mail on port 25 is untouched.

Keep the existing `noreply-dmarc@wikaniagasukses.com` and auto-generated `relay…@wikaniagasukses.com` VERP return-paths working: they are already on the domain, so the domain-wide rule covers them naturally.

No Stalwart principal changes are needed — this is purely a submission-time policy layer. No Ansible role restructuring. All changes live in a single template file.

## Files to Modify

### `infra/roles/stalwart/templates/config.toml.j2`

Add the following block after the outbound relay section (around line 72, end of file):

```toml
# ── Submission policy: lock auth'd From/MAIL FROM to @wikaniagasukses.com ─────
session.mail.script = "enforce-envelope-sender"
session.data.script = "enforce-from-header"

sieve.trusted.scripts.enforce-envelope-sender.contents = '''
require ["variables", "envelope", "reject", "regex", "vnd.stalwart.expressions"];

# Only enforce for authenticated submissions; skip anonymous inbound on :25.
if not string :is "${env.authenticated_as}" "" {
  if not envelope :regex "from" "@wikaniagasukses\\.com$" {
    reject "550 5.7.1 Envelope sender must be on wikaniagasukses.com";
  }
}
'''

sieve.trusted.scripts.enforce-from-header.contents = '''
require ["variables", "envelope", "reject", "regex", "vnd.stalwart.expressions"];

# Only enforce for authenticated submissions; skip anonymous inbound on :25.
if not string :is "${env.authenticated_as}" "" {
  if not header :regex "from" "@wikaniagasukses\\.com(>|\\s|$)" {
    reject "550 5.7.1 From header must be on wikaniagasukses.com";
  }
}
'''
```

Notes:
- Use double-backslash `\\.` in TOML triple-quoted strings — TOML treats `\\` as a literal backslash and Sieve regex then sees `\.`.
- The header regex tolerates the common forms `Name <user@wikaniagasukses.com>` and `user@wikaniagasukses.com`.
- Scripts are named uniquely so they can be referenced from `session.mail.script` / `session.data.script` without collision.

### Deploy

Use the existing command from `CLAUDE.md`:

```bash
ansible-playbook -i infra/inventory.ini infra/primary.yml --tags stalwart
```

The `stalwart` role already reloads the service when the rendered config changes, so no separate restart step is needed.

### smtp2go Dashboard Cleanup (manual)

In the smtp2go dashboard → Sending → Verified Senders, delete the four unverified rows:

- `ticket@smtp2go.com`
- `nochtaricardas@gmail.com`
- `e2eprefix1@example.org`
- `sutantogeraldi@icloud.com`

Verified rows (`noreply-dmarc@wikaniagasukses.com`, `geraldi@wikaniagasukses.com`, `relay1776210530-0e1bc6@wikaniagasukses.com`) stay untouched.

## Reference — Existing Pieces We're Reusing

- Submission listeners `server.listener.submission` (587) and `server.listener.submissions` (465) already require SASL auth via the internal directory — these are the sessions where `${env.authenticated_as}` is populated. (`infra/roles/stalwart/templates/config.toml.j2:27-32`)
- Port 25 listener `server.listener.smtp` is unauthenticated and the guard clause intentionally lets it through unchanged. (`infra/roles/stalwart/templates/config.toml.j2:24-25`)
- Outbound relay routing (`queue.route.relay.*`, `queue.strategy.route`) already unconditionally forwards accepted mail to smtp2go — no change needed there. (`infra/roles/stalwart/templates/config.toml.j2:60-71`)
- Ansible `stalwart` role handler reloads `stalwart-mail.service` on template change. (`infra/roles/stalwart/tasks/main.yml`)

## Verification

Run from a local machine with `swaks` installed and the `geraldi` account's SMTP credentials available.

**1. Baseline — known-good send still works**

```bash
swaks --to you@external.example \
      --from geraldi@wikaniagasukses.com \
      --server mail.wikaniagasukses.com:587 --tls \
      --auth LOGIN --auth-user geraldi --auth-password <pw> \
      --header "Subject: lockdown baseline" --body "legit send"
```

Expected: `250 Ok` at `DATA`, message shows up in smtp2go outbound logs as accepted.

**2. Envelope-from lockdown — foreign MAIL FROM**

```bash
swaks --to you@external.example \
      --from foo@gmail.com \
      --server mail.wikaniagasukses.com:587 --tls \
      --auth LOGIN --auth-user geraldi --auth-password <pw> \
      --header "Subject: lockdown envelope" --body "should bounce"
```

Expected: `550 5.7.1 Envelope sender must be on wikaniagasukses.com` at `MAIL FROM`. No smtp2go traffic.

**3. From-header lockdown — wika envelope but foreign header**

```bash
swaks --to you@external.example \
      --from geraldi@wikaniagasukses.com \
      --server mail.wikaniagasukses.com:587 --tls \
      --auth LOGIN --auth-user geraldi --auth-password <pw> \
      --header "From: Geraldi <sutantogeraldi@icloud.com>" \
      --header "Subject: lockdown header" --body "should bounce"
```

Expected: `550 5.7.1 From header must be on wikaniagasukses.com` at `DATA`. No smtp2go traffic.

**4. Domain-wide permissiveness — geraldi sending as sales@**

```bash
swaks --to you@external.example \
      --from sales@wikaniagasukses.com \
      --server mail.wikaniagasukses.com:587 --tls \
      --auth LOGIN --auth-user geraldi --auth-password <pw> \
      --header "Subject: domain-wide" --body "geraldi sending as sales"
```

Expected: `250 Ok`. Confirms we didn't accidentally lock it to exact-principal match.

**5. Port 25 inbound unaffected**

On the primary host:

```bash
ssh dev@primary
swaks --to geraldi@wikaniagasukses.com --from random@example.org \
      --server 127.0.0.1:25 --header "Subject: inbound" --body "inbound test"
```

Expected: accepted (passed to local delivery). Proves the auth-guard clause skips the checks for unauthenticated inbound.

**6. smtp2go dashboard — 24h follow-up**

After 24h of normal use, reopen the Verified Senders panel. Expected: no new unverified rows have appeared. Existing rows that were just deleted remain gone.

## Risks / Watch-outs

- If the Sieve expression syntax differs in v0.15.5 (docs on `stalw.art` are version-agnostic), the config will fail to parse and `systemctl status stalwart-mail` will show a clear "sieve parse error" with the offending line. Recovery: check journalctl, fix the regex/quoting, re-run the playbook. The service refuses to start on bad config, so we won't silently lose mail.
- `vnd.stalwart.expressions` require may not be needed — it's included defensively to unlock `${env.authenticated_as}`. If the log shows "unknown extension", drop it.
- If any legitimate automation submits with a foreign From (unlikely given the current account list), it will start bouncing the moment the config deploys. Mitigation: test plan step 1 above catches this before we walk away.
