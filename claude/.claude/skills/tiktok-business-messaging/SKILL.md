---
name: tiktok-business-messaging
description: Integrate with the TikTok Business API — OAuth, direct messages, conversations, media, comments, auto-messages (welcome/suggested/chat prompts), video insights, comment-to-message direct replies, and webhook subscriptions for DIRECT_MESSAGE / BRAND_MENTION / VIDEO / COMMENT events. Use when working with `business-api.tiktok.com/open_api/v1.3/business/*` or `tt_user/oauth2/*` endpoints; building TikTok DM bots, inboxes, or comment automation for Business Accounts; handling `im_*`, `brand.mention.event`, `comment.update`, or `post.publish.*` webhooks; or when the user mentions TikTok Business Messaging, TikTok DMs, TikTok Business Account auth, brand mention webhooks, video insights, chat prompts, or `business_id`/`open_id` tokens.
---

# TikTok Business API

Quick guide. The full OpenAPI 3.1 spec (every field, enum, example, "Try-it-now") lives at **<https://tiktok-business-api-docs.pages.dev/>** — go there for exhaustive schemas. This file plus `references/` covers gotchas, common workflows, and progressive lookup.

## Quick start

Base URL: `https://business-api.tiktok.com/open_api/v1.3/`

Auth header on `/business/*` calls: `Access-Token: <short-term token>`. Token valid **1 day**; refresh token valid **1 year**.

1. Share the TikTok account holder authorization URL with the business; capture `code` from the redirect.
2. `POST /tt_user/oauth2/token/` with `auth_code` (valid 10 min, single-use) → returns `access_token`, `refresh_token`, `open_id`.
3. Use `open_id` as `business_id` on every `/business/*` call.
4. `POST /tt_user/oauth2/refresh_token/` before the 1-day expiry.

Send a text message:
```bash
curl -X POST 'https://business-api.tiktok.com/open_api/v1.3/business/message/send/' \
  -H "Access-Token: $ACCESS_TOKEN" -H 'Content-Type: application/json' \
  -d '{"business_id":"'"$OPEN_ID"'","recipient_type":"CONVERSATION","recipient":"'"$CONV"'","message_type":"TEXT","text":{"body":"Hi"}}'
```

## Hard constraints (gotchas)

These are environment-specific facts that defy reasonable assumptions — read these before designing anything:

- **Rate limit:** 10 QPS across Business Messaging endpoints. On error `40100`, back off.
- **48-hour reply windows** (non-mutual follow conversations):
  - After user's first message → up to **10** replies in 48 h.
  - After each user reply → **unlimited** for 48 h.
  - After 48 h of silence → only **3** more messages until they reply again.
- **Cannot initiate** — never message a user who hasn't messaged the business first. The sole exception is `direct_reply` to high-intent comments (VN/ID/TH accounts only).
- **Message is text XOR image**, never both. Text body cap: 6,000 chars (incl. spaces/emoji).
- **`conversation_id` encoding:** URL-encode `+` as `%2B` in query strings, or you'll get *"Param conversation_id is invalid"*.
- **EU/EEA/UK senders** trigger `im_receive_msg_eu` (not `im_receive_msg`). That payload omits sender, conversation_id, and content — you must poll `conversation/list/` + `content/list/` to retrieve the body.
- **Webhook `content` is a stringified JSON** — always `JSON.parse(payload.content)`.
- **Image download** requires header `x-user: <Access-Token>` when GETting the `download_url`.
- **Big number IDs**: `comment.update` webhook serializes `comment_id`/`video_id`/`parent_comment_id` as bare numbers exceeding `Number.MAX_SAFE_INTEGER`. Use a BigInt reviver or `json-bigint` — naïve `JSON.parse` silently truncates.
- **Expiry table:** access token 1 d · refresh token 1 y · auth code 10 min (single-use) · `media_id` 30 d · `download_url` 24 h · profile/sticker/AI-emoji URLs per `x-expires` (typically 30 d).
- **Pagination caps:** conversation list max 100 (past 90 days only). Message list max 20 most recent per conversation. Comment list returns dupes past the first 500.
- **Comment-to-Message** only for Business Accounts in **VN/ID/TH** replying to APAC/LATAM/METAP accounts; five eligibility conditions must all hold per reply (see `references/direct-reply.md`).

## Common errors

| Code | Meaning | Fix |
|------|---------|-----|
| 40001 | No permission | Check app scopes; re-authorize user if scopes changed |
| 40002 | Param error | Read `message` for the field name |
| 40007 | Object doesn't exist | Verify ID + URL path |
| 40064 | DM blocked | Likely outside 48 h window or initiating cold conversation |
| 40100 | Rate limited | Back off; respect 10 QPS |
| 40105 | Bad/expired access token | Refresh via `/tt_user/oauth2/refresh_token/` |
| 40908 | Unsupported file type | JPG/PNG only, ≤ 3 MB for image upload |
| 51065 | System error | Retry with backoff; escalate if persistent |

## Endpoint map & progressive disclosure

26 endpoints across 9 categories. **Load only the reference file whose topic you're working on** — each lives in `references/`:

| Category | Load file | When |
|---|---|---|
| Authentication | `references/authentication.md` | Implementing OAuth flow, refreshing tokens, or introspecting scopes (`/tt_user/oauth2/*`, `/tt_user/token_info/get/`) |
| Messages | `references/messages.md` | Sending DMs (`/business/message/send/`), templates, sender actions, or managing welcome / suggested questions / chat prompts (`/business/message/auto_message/*`) |
| Conversations | `references/conversations.md` | Listing conversations or reading message history (`/business/message/conversation/list/`, `/content/list/`) |
| Media | `references/media.md` | Uploading or downloading images/video attachments (`/business/message/media/upload/`, `/download/`, `/capabilities/get/`) |
| Direct Reply | `references/direct-reply.md` | Toggling Comment-to-Message or replying to a high-intent comment (`/business/message/direct_reply/*`) |
| Comments | `references/comments.md` | Reading or replying to comments on owned videos (`/business/comment/*`) |
| Publish | `references/publish.md` | Polling publish status (`/business/publish/status/`) |
| Videos | `references/videos.md` | Listing posts and engagement insights (`/business/video/list/`) |
| Webhooks | `references/webhooks.md` | Creating, listing, or deleting webhook subscriptions (`/business/webhook/*`) |
| Webhook event payloads | `references/webhook-events.md` | Implementing a callback handler, or you encounter any of: `im_*` event names, `brand.mention.event`, `comment.update`, `post.publish.*`, the `DIRECT_MESSAGE`/`BRAND_MENTION`/`VIDEO`/`COMMENT` `event_type` values, or a webhook `content` JSON payload |

**Canonical schema source:** <https://tiktok-business-api-docs.pages.dev/> — full OpenAPI 3.1 spec with every field, enum, and example. Load when you need an exhaustive schema for a specific endpoint.

## Workflows

**Inbound DM → reply:**
1. `DIRECT_MESSAGE` webhook fires. Handle both `im_receive_msg` and `im_receive_msg_eu` — see `references/webhook-events.md` § EU/EEA caveat (the EU variant is stripped; poll to retrieve content).
2. Parse the envelope's `content` field (stringified JSON) to get `conversation_id`.
3. `POST /business/message/send/` with `recipient_type=CONVERSATION`, `recipient=<conversation_id>`.

**Send an image:**
1. `GET /business/message/capabilities/get/` with `capability_types=["IMAGE_SEND"]` for that conversation. Image sharing isn't available in all country pairs.
2. `POST /business/message/media/upload/` (multipart, JPG/PNG ≤ 3 MB) → `media_id` (valid 30 d).
3. `POST /business/message/send/` with `message_type=IMAGE`, `image.media_id=<media_id>`.

**Reply to a high-intent comment (Comment-to-Message):**
1. Verify `direct_reply/get/` returns `operation_status=ENABLE`. If not, `direct_reply/update/` to enable.
2. From the `im_receive_high_intent_comment` webhook capture `comment_id`.
3. `POST /business/message/send/` with `direct_reply.reply_type=COMMENT_REPLY`, `comment_reply.comment_id=<id>`, `message_type=TEXT`.

**Comment lifecycle webhook → fetch body:**
1. `comment.update` webhook fires (within 5 min of any comment change) with `comment_id`, `video_id`, `comment_action`. **The body is NOT in the payload.**
2. For `insert` events: `GET /business/comment/list/?comment_ids=[<comment_id>]` to fetch text/author/likes.
3. For `delete` events: the comment is gone — the webhook is the only record.

**Video publish lifecycle:**
1. `POST /business/video/publish/` returns `share_id`.
2. Either poll `GET /business/publish/status/?publish_id=<share_id>` until terminal, **or** subscribe to the `VIDEO` webhook for the four-stage lifecycle (`post.publish.failed` / `complete` / `publicly_available` / `no_longer_publicly_available`).
3. `post_id` first appears in `post.publish.publicly_available` (or in `post_ids[]` on the polling endpoint when status flips to `PUBLISH_COMPLETE` — may take up to 3 min). Use it as `video_ids` filter in `/business/video/list/`.

**Manage chat prompts (auto-messages):**
1. `POST /business/message/auto_message/status/update/` with `CHAT_PROMPT` + `ENABLE`. **Destructive:** if any chat prompts already exist, enabling disables all of them.
2. `POST /business/message/auto_message/create/` once per prompt (max 6). Wait for `audit_status=APPROVED` via `auto_message/get/` (a few seconds to ~2–3 h).
3. `POST /business/message/auto_message/sort/` to reorder — pass *all* prompt IDs in the desired order.

## Permission scopes

Webhook event types require specific user-granted scopes to remain valid. Check granted scopes via `POST /tt_user/token_info/get/` (see `references/authentication.md`):

| Webhook | Scope required |
|---|---|
| `im_*` (DIRECT_MESSAGE) | Business Messaging permission |
| `im_auto_message_*` | Additionally requires `message.list.read` |
| `comment.update` (COMMENT) | `comment.list` |
| `post.publish.*` (VIDEO) | TikTok Accounts > Business Content |
| `brand.mention.event` | Mentions permission |
