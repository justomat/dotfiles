# E2E Mail Delivery Diagnosis & Fix: `geraldi@wikaniagasukses.com` Inbound

## Context

Inbound mail to `geraldi@wikaniagasukses.com` (and every other `@wikaniagasukses.com` / `@anugerahsaktisukses.com` recipient) is silently lost. Root cause has already been isolated from Stalwart journald logs — a real iCloud → geraldi message at 12:42:26 passed DKIM/DMARC/SPF, was queued as `queueName = "local"`, then Stalwart attempted delivery to `mail.smtp2go.com` and got a `550 From header sender domain not verified (icloud.com)`.

The culprit is a single config line on primary:

```toml
queue.strategy.route = "'relay'"
```

This expression always evaluates to the literal string `relay`, so **every** queued message — including locally-destined mail — is shipped to smtp2go, which rejects foreign From domains. We need a conditional route that returns `'local'` for local-domain recipients and `'relay'` for everything else.

Goal: fix the route expression, then verify end-to-end inbound + outbound delivery using `swaks` from the local mac.

## Files to Modify

- `/etc/stalwart/config.toml` on `primary` (SSH: `ssh dev@primary`) — single line: `queue.strategy.route`.

No local repo file is touched in this plan. The Ansible Stalwart template currently renders this key verbatim; once the correct expression is confirmed on primary, a follow-up PR should backport the same line into the role template (out of scope for this plan, tracked separately).

## Reference Material

- Live evidence: `sudo journalctl -u stalwart-mail --since "12:40" --until "12:50"` on primary (log block around `queue.queue-message queueName="local"` followed by `outbound.connect-start hostname="mail.smtp2go.com"`).
- Existing route definitions already in the config:
  - `queue.route.local.type = "local"`
  - `queue.route.relay.type = "relay"` (with smtp2go host + auth)
- Admin: user `admin`, password from `infra/vars/secrets.yml` → `stalwart_admin_password: "DOe7cyruMb"`.
- Management API: `http://127.0.0.1:8080` (on primary only).
- Stalwart expression language reference: `stalwart --help` on primary, plus `/usr/share/doc/stalwart/` if present; online docs at `stalw.art/docs/smtp/queue/routing/` were 404 during prior investigation so verify by dry-run on primary before restart.

## Phase A — Reproduce the Failure (Baseline)

Run from the local mac using `swaks` (`/opt/homebrew/bin/swaks`, already installed).

1. **Tail logs on primary** in a second terminal so the delivery attempt is captured live:

   ```bash
   ssh dev@primary "sudo journalctl -u stalwart-mail -f --since '1 min ago'"
   ```

2. **Inject inbound test** (external sender → geraldi) over port 25 STARTTLS:

   ```bash
   swaks --to geraldi@wikaniagasukses.com \
         --from "e2e-prefix-$(date +%s)@example.org" \
         --server mail.wikaniagasukses.com --port 25 \
         --h-Subject "E2E PRE-FIX inbound $(date +%s)" \
         --body "Baseline reproduction. Expect silent loss / relay rejection." \
         --tls
   ```

3. **Expected baseline evidence** in the tailed log:
   - `queue.queue-message queueName="local"` for the message
   - Immediately followed by `outbound.connect-start hostname="mail.smtp2go.com"`
   - Followed by `delivery.failed code=550 details="From header sender domain not verified ..."`
   - Message **not** present in IMAP INBOX (see Phase C step 3 for IMAP check).

If the log instead shows a clean local deliver (`delivery.deliver-local`), the bug has already been fixed out-of-band — stop and re-scope.

## Phase B — Fix `queue.strategy.route`

The expression must dispatch on whether `rcpt_domain` (or `rcpt`) belongs to a locally-hosted domain. Stalwart's expression language supports `if … then … else … endif` and the `is_local_domain(<directory>, <domain>)` function.

1. **Derive the correct expression on primary** — do not guess blindly. Verify candidates by running Stalwart's config-parser in no-start mode before touching the live config:

   ```bash
   # Dry-run parse: copy current config, patch one line, ask stalwart to validate
   sudo cp /etc/stalwart/config.toml /tmp/stalwart-test.toml
   # edit /tmp/stalwart-test.toml with the candidate line
   sudo -u stalwart stalwart --config /tmp/stalwart-test.toml --help 2>&1 | head
   ```

   (The `--help` form boots config parsing far enough to surface expression errors without actually taking the port.)

2. **Candidate expression (starting point — confirm syntax against live parser):**

   ```toml
   queue.strategy.route = "if is_local_domain('*', rcpt_domain) then 'local' else 'relay' endif"
   ```

   Alternate forms to try if the above is rejected:

   - `"if is_local_domain('', rcpt_domain) then 'local' else 'relay' endif"` (empty directory = default)
   - `"if !is_empty(rcpt_domain) && is_local_domain('*', rcpt_domain) then 'local' else 'relay' endif"`
   - Match form: `"match rcpt_domain { 'wikaniagasukses.com' | 'anugerahsaktisukses.com' => 'local', _ => 'relay' }"` (fall-back if `is_local_domain` isn't available in v0.15.5)

   Accept the first candidate whose parse succeeds AND whose semantic test (Phase C) passes.

3. **Apply the fix to live config** after the dry-run succeeds:

   ```bash
   ssh dev@primary
   sudo cp /etc/stalwart/config.toml /etc/stalwart/config.toml.bak-$(date +%s)
   sudo sed -i 's|^queue\.strategy\.route = .*|queue.strategy.route = "<NEW_EXPRESSION>"|' /etc/stalwart/config.toml
   sudo grep '^queue\.strategy\.route' /etc/stalwart/config.toml  # sanity print
   sudo systemctl restart stalwart-mail
   sudo systemctl status stalwart-mail --no-pager | head -20
   sudo journalctl -u stalwart-mail --since "30 sec ago" | tail -40
   ```

   Note: the project CLAUDE.md warns about this exact key — the inline `[{ else = "'relay'" }]` form is a startup parse error. Stay with the single-quoted string-expression form.

4. **Abort condition**: if restart fails or logs show `expression parse error` / `startup failed`, revert:

   ```bash
   sudo cp /etc/stalwart/config.toml.bak-<timestamp> /etc/stalwart/config.toml
   sudo systemctl restart stalwart-mail
   ```

   Then iterate on the expression and repeat the dry-run.

## Phase C — Post-Fix E2E Verification

Goal: prove both directions work, from a cold CLI, with zero GUI involvement.

1. **Inbound repeat** — rerun the Phase A swaks command with a fresh subject (`E2E POST-FIX inbound $(date +%s)`). In the tailed journal, expect:
   - `queue.queue-message queueName="local"`
   - `delivery.deliver-local` (NOT `outbound.connect-start mail.smtp2go.com`)
   - Exit code `0` from swaks, `250 2.0.0 Message queued` server reply.

2. **IMAP read-back** — confirm the message landed in geraldi's INBOX, using `swaks` for IMAP, or openssl + raw IMAP:

   ```bash
   # Option A: one-liner via openssl
   { sleep 1; echo "a1 LOGIN geraldi Wika2026!"; sleep 1; \
     echo "a2 SELECT INBOX"; sleep 1; \
     echo "a3 SEARCH SUBJECT \"E2E POST-FIX inbound\""; sleep 1; \
     echo "a4 LOGOUT"; sleep 1; } \
   | openssl s_client -quiet -connect mail.wikaniagasukses.com:993 2>/dev/null
   ```

   Expect `SEARCH` to return at least one UID and `SELECT` to report EXISTS ≥ 1 increment vs baseline.

3. **Outbound submit** — prove smtp2go relay still works for legit local senders:

   ```bash
   swaks --server mail.wikaniagasukses.com --port 587 \
         --auth LOGIN --auth-user geraldi --auth-password 'Wika2026!' \
         --from geraldi@wikaniagasukses.com \
         --to coccus_parsley_1o@icloud.com \
         --h-Subject "E2E POST-FIX outbound $(date +%s)" \
         --body "Outbound relay health check." \
         --tls
   ```

   In the tailed journal, expect:
   - `queue.queue-message queueName="relay"`
   - `outbound.connect-start hostname="mail.smtp2go.com"`
   - `delivery.delivered` (or similar success) with a 250 response.

   Then confirm receipt in the iCloud inbox (user-side check).

4. **Negative-control** — send *from* an external address *to* the second domain (`@anugerahsaktisukses.com` alias) to confirm the alias domain also routes locally:

   ```bash
   swaks --to geraldi@anugerahsaktisukses.com \
         --from "e2e-alias-$(date +%s)@example.org" \
         --server mail.wikaniagasukses.com --port 25 \
         --h-Subject "E2E POST-FIX alias inbound $(date +%s)" \
         --body "Alias domain routing check." \
         --tls
   ```

   Expect `queueName="local"` and local delivery to geraldi's INBOX (aliases share the same mailbox).

5. **Queue sanity** — list the admin queue and confirm it drains:

   ```bash
   ssh dev@primary "curl -s -u admin:DOe7cyruMb 'http://127.0.0.1:8080/api/queue/messages?page=0&limit=20' | jq '.data.items | length'"
   ```

   Should read `0` shortly after the tests finish. If a stuck message lingers, check its status and failure reason before declaring success.

## Success Criteria (all must hold)

- Phase A baseline reproduces the 550 smtp2go rejection on an unmodified config.
- Phase B config change applied, `stalwart-mail` restart clean (no parse errors in journal).
- Phase C steps 1–4 each complete with the expected log signatures and IMAP read-back.
- Queue empty at end of run; no orphaned messages.

## Follow-Ups (out of scope but noted)

- Backport the fixed `queue.strategy.route` expression into the Ansible Stalwart template so a re-provision doesn't regress the bug.
- Consider whether `sales@wikaniagasukses.com` group deliveries require a separate route or remain covered by the `local` branch (quick verify via a test send to `sales@`).
- Add a lightweight smoke-test cron (one swaks inbound + one IMAP poll per day) once the fix is stable, so silent relay regressions get caught.
