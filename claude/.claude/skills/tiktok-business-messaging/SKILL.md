---
name: tiktok-business-messaging
description: Integrate with the TikTok Business Messaging API and the shared `/business/webhook/update/` plumbing — OAuth authentication, sending/receiving direct messages, conversation and media management, comment-to-message direct replies, chat prompts, plus webhook subscriptions for DIRECT_MESSAGE / BRAND_MENTION / VIDEO / COMMENT event types. Use when working with `business-api.tiktok.com/open_api/v1.3/business/message/*`, `tt_user/oauth2/*`, or `business/webhook/*` endpoints; building TikTok DM bots or inboxes for Business Accounts; handling `im_*`, `brand.mention.event`, or post-publish/comment webhooks; or the user mentions TikTok Business Messaging, TikTok DMs, TikTok Business Account auth, brand mention webhooks, or `business_id`/`open_id` tokens.
---

# TikTok Business Messaging API

## Quick start

Base URL: `https://business-api.tiktok.com/open_api/v1.3/`

Auth header on Business Messaging calls: `Access-Token: <short-term token>`. The token is valid 1 day; refresh token is valid 1 year.

Typical flow:

1. Share the TikTok account holder authorization URL with the business; capture `code` from the redirect.
2. Exchange `auth_code` for tokens via `POST /tt_user/oauth2/token/`. `auth_code` is valid 10 minutes and single-use.
3. Use `data.open_id` from that response as `business_id` on every `/business/message/*` call.
4. Refresh via `POST /tt_user/oauth2/refresh_token/` before the 1-day window closes.

Send a text message:

```bash
curl -X POST 'https://business-api.tiktok.com/open_api/v1.3/business/message/send/' \
  -H "Access-Token: $ACCESS_TOKEN" -H 'Content-Type: application/json' \
  -d '{"business_id":"'"$OPEN_ID"'","recipient_type":"CONVERSATION","recipient":"'"$CONV"'","message_type":"TEXT","text":{"body":"Hi"}}'
```

## Hard constraints

- **Rate limit**: 10 QPS across Business Messaging endpoints. On `40100`, back off.
- **48-hour reply windows** (non-mutual follow conversations):
  - After user's first message: up to 10 messages in 48h.
  - After each user reply: unlimited for 48h.
  - After 48h of silence: only 3 more messages until they reply again.
- **Cannot initiate**: never message a user who hasn't messaged the business first (exception: `direct_reply` to high-intent comments).
- **A message is text XOR image**, never both. Text cap 6000 chars.
- **Media IDs expire after 30 days**; download URLs after 24h; profile/sticker/AI-emoji URLs carry `x-expires` (30d). Re-fetch or re-upload after expiry.
- **Image download** requires header `x-user: <Access-Token>` when GETting the `download_url`.
- **Comment-to-Message** only for Business Accounts in VN/ID/TH replying to APAC/LATAM/METAP accounts; all five eligibility conditions in [REFERENCE.md](REFERENCE.md#comment-to-message-direct-reply) must hold for a reply to succeed.
- **`conversation_id` encoding**: URL-encode `+` as `%2B` in query strings, or you'll get "Param conversation_id is invalid."
- Conversation list returns max 100 results, only from past 90 days. Message list returns max 20 most recent per conversation.

## Common errors

| Code | Meaning | Fix |
|------|---------|-----|
| 40001 | No permission | Check scopes on the dev app; re-auth user if scopes changed |
| 40002 | Param error | Read `message` for the field name |
| 40007 | Object doesn't exist | Verify ID + URL path |
| 40064 | DM blocked by direct-message rules | Likely outside 48h window or initiating a cold convo |
| 40100 | Rate limited | Back off; respect 10 QPS |
| 40105 | Bad/expired access token | Refresh via `/tt_user/oauth2/refresh_token/` |
| 40908 | Unsupported file type | Only JPG/PNG, ≤3MB, for image upload |
| 51065 | System error | Retry with backoff; escalate if persistent |

## Endpoint map

All under `https://business-api.tiktok.com/open_api/v1.3/`.

| Capability | Endpoint | Method |
|---|---|---|
| Get short-term token | `tt_user/oauth2/token/` | POST |
| Refresh token | `tt_user/oauth2/refresh_token/` | POST |
| Send message | `business/message/send/` | POST |
| List conversations | `business/message/conversation/list/` | GET |
| List messages in conversation | `business/message/content/list/` | GET |
| Upload image | `business/message/media/upload/` | POST (multipart) |
| Download media | `business/message/media/download/` | POST |
| Check IMAGE_SEND capability | `business/message/capabilities/get/` | GET |
| Enable/disable Comment-to-Message | `business/message/direct_reply/update/` | POST |
| Get Comment-to-Message status | `business/message/direct_reply/get/` | GET |
| Create webhook config | `business/webhook/update/` | POST |
| Get webhook config | `business/webhook/list/` | GET |
| Delete webhook config | `business/webhook/delete/` | POST |
| List comments on owned video | `business/comment/list/` | GET |
| Reply to a comment | `business/comment/reply/create/` | POST |
| Get post publishing status | `business/publish/status/` | GET |

## Workflows

**Inbound message → reply** ([REFERENCE.md](REFERENCE.md#receiving-and-replying), [WEBHOOKS.md](WEBHOOKS.md#direct_message-events)):
1. `DIRECT_MESSAGE` webhook fires — handle both `im_receive_msg` (non-EU) and `im_receive_msg_eu` (EEA/CH/UK senders only deliver receiver+timestamp; you must poll `conversation/list/` + `content/list/` to retrieve their message body).
2. Parse `content` (it's a stringified JSON in the envelope) to get `conversation_id`.
3. Reply with `POST /business/message/send/`, `recipient_type=CONVERSATION`, `recipient=<conversation_id>`.

**Send image** ([REFERENCE.md](REFERENCE.md#media)):
1. `capabilities/get/` with `capability_types=["IMAGE_SEND"]` for the conversation.
2. `media/upload/` (multipart, `media_type=IMAGE`, JPG/PNG ≤3MB) → `media_id`.
3. `send/` with `message_type=IMAGE`, `image.media_id=<media_id>`.

**Reply to high-intent comment** ([REFERENCE.md](REFERENCE.md#comment-to-message-direct-reply)):
1. Ensure Comment-to-Message is `ENABLE` via `direct_reply/get/`.
2. From webhook `im_receive_high_intent_comment` capture `comment_id`.
3. `send/` with `direct_reply.reply_type=COMMENT_REPLY`, `comment_reply.comment_id=<id>`, `message_type=TEXT`.

## Detailed reference

- [REFERENCE.md](REFERENCE.md) — full request/response shapes for every endpoint, all `message_type` variants (TEXT, IMAGE, SHARE_POST, TEMPLATE QA_BUTTON_CARD/QA_LINK_CARD, SENDER_ACTION TYPING/MARK_READ, referenced replies, direct replies), webhook subscription endpoints, chat prompts workflow.
- [WEBHOOKS.md](WEBHOOKS.md) — every webhook event payload: all `im_*` events under `DIRECT_MESSAGE` (including the stripped EU/EEA variant), `brand.mention.event`, plus `VIDEO`/`COMMENT` post & comment events. Includes the envelope format (note: `content` is a stringified JSON) and per-event content schemas.
