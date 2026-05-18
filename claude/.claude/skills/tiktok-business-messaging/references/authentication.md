# Authentication

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Authentication>

Base URL: `https://business-api.tiktok.com/open_api/v1.3/`. Auth endpoints **do not** use the `Access-Token` header — credentials go in the request body.

## Authorization flow (one-time per business)

1. Configure your developer app: app logo, redirect URL (`My Apps > App Detail > Basic Information > TikTok account holder redirect URLs`), `Business Messaging` permission selected.
2. Share the `TikTok account holder authorization URL` (found in App Detail) with the business. Optionally append `&state=<csrf>` for CSRF protection and `&disable_auto_auth=1` to disable silent re-redirect for already-authorized users.
3. The business clicks **Authorize**, granting whichever scopes your app requested (send messages, read inbox, read account type, etc.).
4. Redirect carries `?code=<auth_code>` — valid 10 min, single-use.

## POST `/tt_user/oauth2/token/` — exchange auth_code

```json
{
  "client_id": "<app id>",
  "client_secret": "<app secret>",
  "grant_type": "authorization_code",
  "auth_code": "<code from redirect>",
  "redirect_uri": "<must match registered>"
}
```

Response `data`:
- `access_token` — short-term, **1 day**.
- `expires_in` — seconds remaining (`86400`).
- `refresh_token` — **1 year**, used to renew.
- `refresh_token_expires_in` — seconds.
- `open_id` — **this is `business_id` for all subsequent calls.**
- `scope` — comma-separated granted scopes.
- `token_type` — `Bearer`.

## POST `/tt_user/oauth2/refresh_token/`

```json
{
  "client_id": "...",
  "client_secret": "...",
  "grant_type": "refresh_token",
  "refresh_token": "..."
}
```

Returns the same `data` shape. **Persist the new `refresh_token` every time** — it may rotate. When the refresh token expires (~1 year), re-run the user authorization flow.

## POST `/tt_user/token_info/get/`

Introspect an access token — useful for checking which scopes a user has granted before calling a scope-gated endpoint.

**Auth quirk:** this endpoint does *not* use the `Access-Token` header. Both `app_id` and `access_token` go in the JSON body:

```json
{
  "app_id": "<your app id>",
  "access_token": "<token to introspect>"
}
```

Response `data`:
- `app_id`
- `creator_id` — **this is `business_id`** for Accounts API calls.
- `scope` — comma-separated granted scopes, e.g. `"video.list,user.info.basic,comment.list,video.insights"`.

## Common scope strings

| Scope | Required for |
|---|---|
| `message.list.send` | `/business/message/send/` |
| `message.list.read` | DM webhooks, auto-message webhooks |
| `message.list.manage` | DM management endpoints |
| `comment.list` | `/business/comment/*` reads, `comment.update` webhook |
| `comment.list.manage` | Comment replies, moderation |
| `video.list` | Basic post fields in `/business/video/list/` |
| `video.insights` | Analytics fields in `/business/video/list/` (audience breakdowns, retention) |
| `user.account.type` | Account type lookup |
