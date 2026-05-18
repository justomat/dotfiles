# Webhooks (REST subscription endpoints)

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Webhooks>

For event payloads (envelopes, content schemas, per-event details), see [webhook-events.md](webhook-events.md). This file covers only the REST endpoints for managing subscriptions.

## Subscription model

Subscribe at the **developer app** level — one subscription per `event_type` per app. The subscription applies to every business that has authorized your app; **no per-business resubscription needed.**

Supported `event_type` values:

| `event_type` | Triggers | Required app permission |
|---|---|---|
| `DIRECT_MESSAGE` | All `im_*` direct-message events | Business Messaging |
| `BRAND_MENTION` | `brand.mention.event` (captions + comments mentioning the business; 2–3 h latency) | Mentions |
| `VIDEO` | `post.publish.*` lifecycle events | TikTok Accounts > Business Content |
| `COMMENT` | `comment.update` — comment/reply created, deleted, or visibility changed | TikTok Accounts > Business Comment + user-granted `comment.list` scope |

## POST `/business/webhook/update/`

Create or update a subscription for one `event_type`.

```json
{"app_id":"...","secret":"...","event_type":"DIRECT_MESSAGE","callback_url":"https://..."}
```

For `event_type: "COMMENT"`, optionally scope to specific posts with `"item_list": ["<video_id>", ...]`. Omit to subscribe to comments on all posts.

**Auth:** uses `app_id` + `secret` in the body — no `Access-Token` header (no user context, this is an app-level operation).

## GET `/business/webhook/list/`

Query: `app_id`, `secret`, `event_type`.

- If `callback_url` is absent from `data`, **no subscription exists** for that event type.
- For `event_type=COMMENT` with a scoped subscription, `data.item_list[]` echoes back the configured `video_id`s.

## POST `/business/webhook/delete/`

Same body as `update/` minus `callback_url`. Delete is **per `event_type`** — you can have other event types still subscribed.
