# Conversations

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Conversations>

## GET `/business/message/conversation/list/`

Query params:
- `business_id` (required)
- `conversation_type` (required): `STRANGER` (user messaged, business hasn't replied) | `SINGLE` (business has replied at least once)
- `limit` — 1–100, default 100
- `cursor` — pagination, default 0

Response `data`:
- `conversations[]` with `conversation_id`, `update_time` (ms), `referral` (may contain `ad[]` array of historical referral ads with `advertiser_id`/`ad_id`/`ad_name`/`embed_url`/`message_material_id`, or `short_link[]` with `ref`, `prefilled_message`, `prefilled_message_audit_status` of `PASS`/`REJECT`).
- `has_more`, `cursor` — pass `cursor` to next call when `has_more`.

**Caps:** past 90 days only, max 100 conversations total returned.

## GET `/business/message/content/list/`

Query params: `business_id`, `conversation_id`.

**Encoding gotcha:** URL-encode `+` in `conversation_id` as `%2B`, or you'll get *"Param conversation_id is invalid"*.

Response `data`:
- `participants[]` — each `{role, id, display_name, profile_image, is_follower?}` where `role` is `BUSINESS_ACCOUNT` | `PERSONAL_ACCOUNT`. `profile_image` URL expires per `x-expires`. `is_follower` only present for personal accounts.
- `messages[]` — **max 20 most recent**. Each message:
  - `message_id`, `conversation_id`, `sender`, `recipient`, `timestamp` (ms).
  - `from_user{role,id}`, `to_user{role,id}`.
  - `message_type`: `TEXT` | `IMAGE` | `SHARE_POST` | `VIDEO` | `EMOJI` | `STICKER` | `TEMPLATE` | `OTHER`.
  - Type-specific blocks: `text.body`, `image.media_id`, `share_post.embed_url`, `video.media_id`, `sticker.url`, `emoji.url`, `template{type,title,buttons[]}`.
  - `message_tag.source`: `APP` | `WEB` | `API` | `OTHERS` | `UNKNOWN_SOURCE`.
  - `auto_message_type`: `WELCOME_MESSAGE` | `SUGGESTED_QUESTION` | `AUTO_REPLY` (omitted for non-automatic).
  - `reactions[]` — `{type:EMOJI|AI_EMOJI, emoji?, ai_emoji_url?, unique_identifier, timestamp}`. AI-emoji URLs expire 30 d.
  - `referenced_message_info.referenced_message_id` for replies. Text content is present when `message_type=TEXT`; **not retrievable via API** when `message_type=OTHER`.

## EU/EEA caveat

EU/Switzerland/UK senders trigger `im_receive_msg_eu` webhooks (see [webhook-events.md](webhook-events.md)) which contain only receiver + timestamp — no sender, no `conversation_id`, no body. To find their message you must enumerate this endpoint after the webhook fires.
