# TikTok Business Messaging API — Reference

Base URL: `https://business-api.tiktok.com/open_api/v1.3/`

Every success response shares: `code` (0 on success), `message`, `request_id`, `data`.

## Authorization & Authentication

### Authorization (one-time per business)

1. Configure your developer app: app logo, redirect URL (`My Apps > App Detail > Basic Information > TikTok account holder redirect URLs`), `Business Messaging` permission selected.
2. Share `TikTok account holder authorization URL` (found in App Detail) with the business. Optionally append `&state=<csrf>` and `&disable_auto_auth=1` (disables silent re-redirect for already-authorized users).
3. Business clicks Authorize, granting: send messages, read inbox, read account type, read+manage messages.
4. Redirect carries `?code=<auth_code>` (valid 10 min, single-use).

### POST `/tt_user/oauth2/token/` — exchange auth_code

Request body (JSON, no Access-Token header):

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
- `open_id` — **this is `business_id` for all subsequent calls**.
- `scope` — comma-separated granted scopes.
- `token_type` — `Bearer`.

### POST `/tt_user/oauth2/refresh_token/`

```json
{
  "client_id": "...",
  "client_secret": "...",
  "grant_type": "refresh_token",
  "refresh_token": "..."
}
```

Returns the same `data` shape; persist the new `refresh_token` each time. When refresh token expires (~1 year), re-run user authorization.

## Receiving and replying

### POST `/business/message/send/`

Headers: `Access-Token: <token>`, `Content-Type: application/json`.

Common body fields:

| Field | Required? | Notes |
|---|---|---|
| `business_id` | always | `open_id` from token response |
| `recipient_type` | when not `direct_reply` | only `CONVERSATION` |
| `recipient` | when not `direct_reply` | `conversation_id` |
| `message_type` | always | `TEXT` \| `IMAGE` \| `SHARE_POST` \| `TEMPLATE` \| `SENDER_ACTION` |
| `text.body` | when `TEXT` | ≤6000 chars (incl spaces/emoji) |
| `image.media_id` | when `IMAGE` | from `media/upload/` |
| `share_post.item_id` | when `SHARE_POST` | post ID from `/business/video/list/`; only your own posts |
| `template` | when `TEMPLATE` | see below |
| `sender_action` | when `SENDER_ACTION` | `TYPING` (5s indicator) \| `MARK_READ` |
| `referenced_message_info.referenced_message_id` | for quoted reply | combine with `message_type=TEXT` only |
| `direct_reply` | for comment reply | see Comment-to-Message section |

Response `data.message.message_id` — empty string `""` for `SENDER_ACTION` since nothing is actually sent.

### TEMPLATE bodies

```json
"template": {
  "type": "QA_BUTTON_CARD",   // or "QA_LINK_CARD"
  "title": "Your question (≤40 chars)",
  "buttons": [
    {"type":"REPLY","title":"Answer 1","id":"opt_1"},
    {"type":"REPLY","title":"Answer 2","id":"opt_2"}
  ]
}
```

- 1–3 buttons. Button `title` cap: **20 chars** for `QA_BUTTON_CARD`, **40 chars** for `QA_LINK_CARD`.
- Self-defined `id` ≤40 chars to distinguish click sources in webhook events.

### Send-message examples

Text reply (quoted):
```json
{
  "business_id": "...", "recipient_type":"CONVERSATION", "recipient":"<conversation_id>",
  "message_type":"TEXT", "text":{"body":"Got it"},
  "referenced_message_info":{"referenced_message_id":"<msg id>"}
}
```

Typing indicator:
```json
{"business_id":"...","recipient_type":"CONVERSATION","recipient":"<conv>","message_type":"SENDER_ACTION","sender_action":"TYPING"}
```

Mark as read:
```json
{"business_id":"...","recipient_type":"CONVERSATION","recipient":"<conv>","message_type":"SENDER_ACTION","sender_action":"MARK_READ"}
```

Share own TikTok post:
```json
{"business_id":"...","recipient_type":"CONVERSATION","recipient":"<conv>","message_type":"SHARE_POST","share_post":{"item_id":"<video id>"}}
```

## Conversations

### GET `/business/message/conversation/list/`

Query params:
- `business_id` (required)
- `conversation_type` (required): `STRANGER` (user messaged, business hasn't replied) | `SINGLE` (business has replied at least once)
- `limit` — 1–100, default 100
- `cursor` — pagination, default 0

Response `data`:
- `conversations[]` with `conversation_id`, `update_time` (ms), `referral` (may contain `ad[]` array of historical referral ads with `advertiser_id`/`ad_id`/`ad_name`/`embed_url`/`message_material_id`, or `short_link[]` with `ref`, `prefilled_message`, `prefilled_message_audit_status` of `PASS`/`REJECT`).
- `has_more`, `cursor` — pass `cursor` to next call when `has_more`.

Only past 90 days, max 100 total returned.

### GET `/business/message/content/list/`

Query params: `business_id`, `conversation_id` (URL-encode `+` as `%2B`).

Response `data`:
- `participants[]` — each `{role, id, display_name, profile_image, is_follower?}` where `role` is `BUSINESS_ACCOUNT` | `PERSONAL_ACCOUNT`. `profile_image` URL expires per `x-expires`. `is_follower` only present for personal accounts.
- `messages[]` — max 20 most recent. Each message:
  - `message_id`, `conversation_id`, `sender`, `recipient`, `timestamp` (ms).
  - `from_user{role,id}`, `to_user{role,id}`.
  - `message_type`: `TEXT` | `IMAGE` | `SHARE_POST` | `VIDEO` | `EMOJI` | `STICKER` | `TEMPLATE` | `OTHER`.
  - Type-specific blocks: `text.body`, `image.media_id`, `share_post.embed_url`, `video.media_id`, `sticker.url`, `emoji.url`, `template{type,title,buttons[]}`.
  - `message_tag.source`: `APP` | `WEB` | `API` | `OTHERS` | `UNKNOWN_SOURCE`.
  - `auto_message_type`: `WELCOME_MESSAGE` | `SUGGESTED_QUESTION` | `AUTO_REPLY` (omitted for non-automatic).
  - `reactions[]` — `{type:EMOJI|AI_EMOJI, emoji?, ai_emoji_url?, unique_identifier, timestamp}`. AI-emoji URLs expire 30d.
  - `referenced_message_info.referenced_message_id` for replies (text content present when `message_type=TEXT`; not retrievable via API when `message_type=OTHER`).

## Media

### POST `/business/message/media/upload/`

Multipart form. Headers: `Access-Token`, `Content-Type: multipart/form-data`.

Form fields:
- `business_id`
- `file` — JPG or PNG, ≤3MB
- `media_type` — `IMAGE` (only supported value)

Response `data.media_id` — valid 30 days. After expiry re-upload.

### POST `/business/message/media/download/`

JSON body:
```json
{
  "business_id":"...","conversation_id":"...","message_id":"...",
  "media_id":"...","media_type":"IMAGE"   // or VIDEO
}
```

Response `data.download_url` — valid 24h. **When GETting it, set header `x-user: <Access-Token>`** or the download will fail.

### GET `/business/message/capabilities/get/`

Query: `business_id`, `capability_types=["IMAGE_SEND"]`. When `IMAGE_SEND` is requested you must also pass `conversation_id` and `conversation_type` (`STRANGER`|`SINGLE`).

Response `data.capability_infos[].capability_result` boolean per `capability_type`. Image attachments are restricted to country pairs that support them.

## Comment-to-Message (direct reply)

Eligibility for the Business Account: VN/ID/TH registration, owner ≥18, Registered Business or has run Messaging Ads, messaging permissions for "Potential connections" + "Other on TikTok" set to "Requests". After enabling, replies are only allowed to APAC/LATAM/METAP-registered commenters.

### POST `/business/message/direct_reply/update/`

```json
{"business_id":"...","direct_reply_type":"COMMENT_TO_MESSAGE","operation_status":"ENABLE"}  // or DISABLE
```

### GET `/business/message/direct_reply/get/`

Query: `business_id`, `direct_reply_type=COMMENT_TO_MESSAGE`. Returns `operation_status: ENABLE|DISABLE`.

### Sending a comment reply

Use `/business/message/send/` with `direct_reply` instead of `recipient_type`/`recipient`:

```json
{
  "business_id":"...",
  "direct_reply":{
    "reply_type":"COMMENT_REPLY",
    "comment_reply":{"comment_id":"<high-intent comment id>"}
  },
  "message_type":"TEXT",
  "text":{"body":"Reply text"}
}
```

All must hold for success:
- Comment is a **first-level** comment on the Business Account's own video.
- Reply within 48h of the comment.
- Comment has no prior reply (app or API).
- No DM activity between the commenter and the Business Account in the past 24h.
- Commenter ≥18 years old.

Get `comment_id` from webhook event `im_receive_high_intent_comment`.

## Comments (REST)

Companion endpoint to the `COMMENT` / `comment.update` webhook — use this to fetch the full body of a comment after the webhook tells you something changed.

### GET `/business/comment/list/`

Headers: `Access-Token`.

Query params:

| Field | Required | Notes |
|---|---|---|
| `business_id` | yes | `open_id` from token response |
| `video_id` | yes | from `/business/video/list/` |
| `comment_ids` | no | JSON-array string, up to 30, to filter specific comments/replies |
| `include_replies` | no | `true` returns up to 3 replies per top-level comment (smart-sorted). For all replies use `/business/comment/reply/list/` |
| `status` | no | `PUBLIC` \| `ALL` (default `ALL`, includes owner-hidden + system-moderated) |
| `sort_field` | no | `likes` \| `replies` \| `create_time` (default random) |
| `sort_order` | no | `asc` \| `desc` \| `smart` (default `smart`) |
| `cursor` | no | from previous response when `has_more` |
| `max_count` | no | 1–30, default 20 — may return fewer even when `has_more=true` due to trust & safety filtering |

**v1.2 → v1.3 migration:** path changed `/business/comments/list/` → `/business/comment/list/`, method `POST` → `GET`, new params `comment_ids` + `include_replies`, new response fields `parent_comment_id`, `reply_list[]`, `unique_identifier`, `display_name`, `image_url`.

Beyond the first 500 comments the endpoint switches to reverse-sort by likes and does **not** dedupe — pagination past 500 may return duplicates.

Response `data`:

- `comments[]` — each comment has:
  - `comment_id`, `video_id`, `create_time` (string, Unix seconds), `text`.
  - `likes`, `replies` (counts), `liked` (by video owner), `pinned`, `owner` (was it the video owner), `status` (`PUBLIC` | `HIDDEN`).
  - User: `username`, `display_name`, `profile_image` (temp URL, see `x-expires`), `unique_identifier` (stable cross-API), `user_id` (deprecated — prefer `unique_identifier`).
  - `parent_comment_id` — returned **only for replies**. Use its presence to distinguish replies from top-level comments.
  - `image_url` — present when the comment is an image. URL does not expire.
  - `reply_list[]` — present only on top-level comments when `include_replies=true`, max 3 entries, each with the same shape as a comment (plus `parent_comment_id`).
- `cursor`, `has_more`.

### POST `/business/comment/reply/create/`

Reply to a comment on an owned (or others') video. Companion to `comment/list/` + the `comment.update` webhook.

Headers: `Access-Token`, `Content-Type: application/json`.

Body:

| Field | Required | Notes |
|---|---|---|
| `business_id` | yes | `open_id` |
| `video_id` | yes | from `/business/video/list/` (`item_id`) |
| `comment_id` | yes | parent comment to reply to |
| `text` | conditional | required if no `image_uri`; ≤150 chars UTF-8 |
| `image_uri` | conditional | required if no `text`; obtain from `/business/comment/image/upload/` |
| `image_width` | conditional | required with `image_uri` (from upload response) |
| `image_height` | conditional | required with `image_uri` (from upload response) |
| `reply_image_url` | no | publicly accessible HTTPS image URL (alternative to `image_uri`). Constraints: 1080×1920 or 1920×1080 max, 360×360 min, ≤20 MB, JPG/JPEG/WebP/PNG. **URL host must be a verified URL property** on the dev app |

Response `data`: `comment_id` (the new reply), `parent_comment_id`, `video_id`, `create_time` (Unix seconds, string), `text` (when text reply) or `image_url` (when image reply — non-expiring), `unique_identifier`, `user_id` (deprecated).

**Spam guard:** the docs warn that posting many similar-content replies in a short window can get them flagged as spam and silently hidden — in which case you won't even receive the `comment.update` event with `comment_action=set_to_public`. Throttle and vary content.

## Publish status (REST polling alternative to the VIDEO webhook)

### GET `/business/publish/status/`

Poll the outcome of `/business/video/publish/` or `/business/photo/publish/` tasks. The push equivalent is the `VIDEO` webhook (payload schema not yet documented in this skill).

Headers: `Access-Token`.

Query: `business_id`, `publish_id` (the `share_id` returned by `/video/publish/` or `/photo/publish/`).

Response `data`:

- `status` — one of:
  - `PROCESSING_DOWNLOAD` — fetching content from the URL you supplied (file-URL flow only).
  - `PUBLISH_COMPLETE` — moderation passed, post is live.
  - `FAILED` — terminal failure.
  - `SEND_TO_USER_INBOX` — draft uploaded and a notification was sent to the creator's inbox (for the draft-publishing flow).
- `post_ids[]` — present **only when `PUBLISH_COMPLETE`** and the posts are publicly viewable. May take **up to 3 minutes** to appear after the status flips — retry if absent. Feed these to `/business/video/list/`'s `video_ids` filter to read metrics.
- `reason` — present only when `FAILED`. Example: `frame_rate_check_failed`. Cross-reference TikTok's "Failure reasons" page for the full list.

## Webhooks

Subscribe at the **developer app** level. One subscription per `event_type` per app — applies to every business that authorizes the app.

Supported `event_type` values:

| `event_type` | Triggers | Permission needed on dev app |
|---|---|---|
| `DIRECT_MESSAGE` | All `im_*` direct-message events | Business Messaging |
| `BRAND_MENTION` | `brand.mention.event` (caption + comment mentions; 2–3h latency) | Mentions |
| `VIDEO` | Post publishing status changes from `/business/video/publish/` & `/business/photo/publish/` | TikTok Accounts > Business Content |
| `COMMENT` | Comment/reply created/deleted/visibility changed on owned public videos | TikTok Accounts > Business Comment |

For event payloads (envelope + per-event content), see [WEBHOOKS.md](WEBHOOKS.md).

### POST `/business/webhook/update/` — create or update

```json
{"app_id":"...","secret":"...","event_type":"DIRECT_MESSAGE","callback_url":"https://..."}
```

For `event_type: "COMMENT"`, optionally scope to specific posts with `"item_list": ["<video_id>", ...]`. Omit to subscribe to all posts.

### GET `/business/webhook/list/`

Query: `app_id`, `secret`, `event_type`. If `callback_url` is absent from `data`, no subscription exists for that event type. For `event_type=COMMENT` with a scoped subscription, `data.item_list[]` echoes back the configured `video_id`s.

### POST `/business/webhook/delete/`

Same body as create minus `callback_url`. Delete is per `event_type`.

## Chat prompts (auto-messages)

Up to 6 chat prompts per Business Account — interactive buttons over the input box.

Workflow:
1. `POST /business/message/auto_message/status/update/` — `auto_message_type=CHAT_PROMPT`, `operation_status=ENABLE`. (May already be enabled by default for some Registered Business Accounts; verify with `auto_message/get/`.)
2. `POST /business/message/auto_message/create/` — `auto_message_type=CHAT_PROMPT`, with `chat_prompt` object body.
3. `GET /business/message/auto_message/get/` with `auto_message_type=CHAT_PROMPT` — confirm each prompt's `audit_status=APPROVED` and `operation_status=ENABLE`. `REVIEWING` resolves in seconds to ~2–3 hours.
4. On `audit_status=REJECTED`: `POST /business/message/auto_message/update/` to edit, then re-check.
5. On `operation_status=DISABLE`: re-enable via step 1.

## Limits recap

- Rate: 10 QPS Business Messaging endpoints.
- Conversation list: max 100, past 90 days.
- Message list: max 20 most recent per conversation.
- Text body: 6000 chars. Image: 3MB JPG/PNG. Template title: 40 chars. Button title: 20 (QA_BUTTON_CARD) / 40 (QA_LINK_CARD). Buttons per template: 1–3.
- `media_id`: 30d. `download_url`: 24h. Profile/sticker/AI-emoji URLs: see `x-expires` (typically 30d).
- Access token: 1 day. Refresh token: 1 year. Auth code: 10 min, single-use.
- 48-hour messaging windows (non-mutual follow): first user msg → 10 in 48h; each user reply → unlimited 48h; >48h silence → 3 more allowed.
