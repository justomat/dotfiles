# Fix: geraldi can't login to Stalwart webmail

## Context

geraldi@wikaniagasukses.com can authenticate via JMAP Basic auth (`/jmap/session` returns HTTP 200) but the webmail UI shows "You are not authorized to access this service." The webmail uses OAuth2 for authentication, not Basic auth.

## Root Cause

**Missing `authenticate-oauth` permission.** geraldi's current permissions are:
- `authenticate`, `email-receive`, `email-send`, `imap-authenticate`

The Stalwart permissions docs list `authenticate-oauth` as a separate permission required for OAuth2 flows. The webmail uses OAuth2 device_code flow, so without `authenticate-oauth`, the OAuth2 authorization step is rejected.

**Secondary issue:** OIDC discovery (`/.well-known/openid-configuration`) returns `http://mail.wikaniagasukses.com:8080` for all endpoints instead of `https://mail.wikaniagasukses.com`. Despite `server.http.base-url` and `server.url` being set correctly, Stalwart may need a restart to pick these up for OIDC URL construction.

## Fix Steps (Gemini tasks)

### Step 1: Add `authenticate-oauth` to geraldi's permissions
PATCH `/api/principal/geraldi` with updated `enabledPermissions` array adding `authenticate-oauth`.

### Step 2: Restart Stalwart
`sudo systemctl restart stalwart-mail` to ensure OIDC issuer URL picks up `server.http.base-url`.

### Step 3: Verify OIDC issuer URL
Check `/.well-known/openid-configuration` returns `https://mail.wikaniagasukses.com` as issuer after restart.

### Step 4: Test webmail login
Verify geraldi can log in at `https://mail.wikaniagasukses.com`.

## Gemini Prompt

```
SSH to primary server as dev@primary (sudo password: lastP@$).

Do these steps IN ORDER:

1. Add authenticate-oauth permission to geraldi:
   curl -s -u "admin:DOe7cyruMb" -X PATCH http://127.0.0.1:8080/api/principal/geraldi \
     -H "Content-Type: application/json" \
     -d '{"enabledPermissions":["authenticate","authenticate-oauth","email-receive","email-send","imap-authenticate"]}'

2. Restart Stalwart:
   printf "lastP@$\n" | sudo -S systemctl restart stalwart-mail

3. Wait 3 seconds, then verify OIDC issuer:
   curl -s http://127.0.0.1:8080/.well-known/openid-configuration | jq .issuer

4. Verify geraldi's updated permissions:
   curl -s -u "admin:DOe7cyruMb" http://127.0.0.1:8080/api/principal/geraldi | jq ".data.enabledPermissions"

Report the output of each step.
```

## Verification
- OIDC issuer should be `https://mail.wikaniagasukses.com` (not `http://...:8080`)
- geraldi's permissions should include `authenticate-oauth`
- User tests webmail login at https://mail.wikaniagasukses.com
