# TikTok Business — Webhook Events

**Authoritative schemas:** the full OpenAPI 3.1 spec with every event's request/response and named schemas in `components/schemas` is at <https://tiktok-business-api-docs.pages.dev/#tag/Webhooks>. This file is a quick-lookup companion focused on gotchas and non-obvious behaviour.

All TikTok business webhooks (Business Messaging, Mentions, Accounts post/comment events) are subscribed via `POST /business/webhook/update/` at the **developer app** level and share the same outer envelope. POSTed to your callback URL as `application/json`.

Available `event_type` values:

| `event_type` | Covers | Required app permission |
|---|---|---|
| `DIRECT_MESSAGE` | All `im_*` events below | Business Messaging |
| `BRAND_MENTION` | `brand.mention.event` (captions + comments mentioning the business) | Mentions |
| `VIDEO` | Post publishing status changes (via `/business/video/publish/`, `/business/photo/publish/`) | TikTok Accounts > Business Content |
| `COMMENT` | `comment.update` — comment/reply created, deleted, or visibility changed on owned posts | TikTok Accounts > Business Comment + user-granted `comment.list` scope |

`COMMENT` subscription accepts an optional `item_list: [video_id, ...]` to scope to specific posts.

## DIRECT_MESSAGE events

`DIRECT_MESSAGE` covers all the `im_*` events documented in the rest of this file.

## Envelope (every event)

```json
{
  "client_key": "<your app_id>",
  "event": "<event name>",
  "create_time": 1714430514,            // seconds
  "user_openid": "<business_id>",       // the open_id of the Business Account
  "content": "<JSON-string of event-specific payload>"
}
```

**`content` is a stringified JSON** — parse it before use (`JSON.parse(payload.content)`).

`client_key` is your developer app ID, **not** the user/business ID. Use `user_openid` to route to the right Business Account.

Inside `content` payloads, `role` enum values are lowercase (`business_account`, `personal_account`), unlike the REST APIs which use uppercase (`BUSINESS_ACCOUNT`, `PERSONAL_ACCOUNT`). Same for `type` (lowercase: `text`, `image`, `share_post`, `video`, `emoji`, `sticker`, `reaction`, `template`).

## Event index

| `event` | Fires when | Notes |
|---|---|---|
| `im_send_msg` | Your Business Account sent a message | Echoes outbound (incl. via app/web) |
| `im_receive_msg` | User **outside** EEA/CH/UK sent you a message | Full content payload |
| `im_receive_msg_eu` | User **inside** EEA/CH/UK sent you a message | **Stripped payload** — no content/sender details, just receiver + timestamp |
| `im_referral_msg` | User entered the conversation via Click-to-Message Ad or `tiktok.me` link | Get attribution before reply |
| `im_mark_read_msg` | Personal Account user marked the session read | Not fired when Business marks read |
| `im_auto_message_config_update` | Auto-message created/updated/deleted/enabled/disabled (within 5 min) | Requires `message.list.read` scope |
| `im_auto_message_audit_update` | Auto-message approved or rejected (within 5 min) | Requires `message.list.read` scope |
| `im_receive_high_intent_comment` | High-intent comment received on your video | Requires Comment-to-Message enabled |

## EU/EEA caveat (load-bearing)

You **must** handle both `im_receive_msg` and `im_receive_msg_eu`. EU/EEA/UK senders only deliver:

```json
{
  "to": "<your username>",
  "to_user": {"id": "<business_id>", "role": "business_account"},
  "timestamp": 1701090879815
}
```

No `from`, no `conversation_id`, no message body. To get content for EU senders, you need to poll `/business/message/conversation/list/` and `/business/message/content/list/` separately.

## Content schemas

### `im_send_msg` content (outbound mirror)

```jsonc
{
  "from": "<sender username>",
  "to": "<receiver username>",
  "unique_identifier": "<TikTok user unique id in conversation>",
  "from_user": {"id": "<id>", "role": "business_account"},
  "to_user": {"id": "<id>", "role": "personal_account"},
  "referenced_message_info": {"referenced_message_id": "<msg id>"},  // when replying
  "conversation_id": "<conv id>",
  "message_id": "<msg id>",
  "timestamp": 1701090879815,           // ms
  "type": "text|image|share_post|video|emoji|sticker|reaction|template",
  // type-specific blocks (mutually exclusive):
  "text":       {"body": "..."},
  "image":      {"media_id": "..."},
  "share_post": {"embed_url": "...", "video_id": "..."},
  "video":      {"media_id": "..."},
  "sticker":    {"url": "...x-expires=..."},          // 30d
  "emoji":      {"url": "..."},                       // no expiry
  "reaction": [{                                       // ADD or REMOVE
     "operation": "ADD",
     "type": "EMOJI",                                  // or AI_EMOJI
     "emoji": "👍",                                    // when EMOJI
     "ai_emoji_url": "...",                            // when AI_EMOJI (30d)
     "unique_identifier": "<reactor id>",
     "timestamp": 1719447205701,
     "original_msg_id": "<msg the reaction is on>"
  }],
  "template": {
    "type": "qa_button_card",                          // or qa_link_card
    "elements": [{
      "title": "Pre-set question",
      "buttons": [{"text":"Answer 1","type":"REPLY","id":"opt_1"}]
    }]
  },
  "auto_message_type": "WELCOME_MESSAGE|SUGGESTED_QUESTION|AUTO_REPLY",  // only when auto
  "scene_type": 0,
  "is_follower": true,
  "message_tag": {"source": "APP|WEB|API|OTHERS|UNKNOWN_SOURCE"}
}
```

### `im_receive_msg` content (non-EU inbound)

Same shape as `im_send_msg` content, with `from_user.role=personal_account` and `to_user.role=business_account`. Additionally:

```jsonc
{
  // ... all fields above ...
  "reply_source_payload": {                            // only when type=text AND auto-generated from a Q&A card click
    "reply_source_msg_id": "<id of the auto-sent reply>",
    "reply_source_unique_id": "<the button id you defined>"
  }
}
```

Use `reply_source_unique_id` to attribute Q&A button clicks back to the option the user picked.

### `im_receive_msg_eu` content (EU inbound)

```jsonc
{
  "to": "<username>",
  "to_user": {"id": "<business_id>", "role": "business_account"},
  "timestamp": 1701090879815
}
```

That's it. No sender, no content. See "EU/EEA caveat" above.

### `im_referral_msg` content

```jsonc
{
  "from": "<user>", "to": "<business>",
  "unique_identifier": "<user id>",
  "from_user": {"id": "...", "role": "personal_account"},
  "to_user":   {"id": "...", "role": "business_account"},
  "conversation_id": "...",
  "timestamp": 1701090879815,
  "is_follower": true,
  "referral": {
    "source": "ad",                                    // or "short_link"
    "ad": {                                            // when source=ad
      "advertiser_id": "...",
      "ad_id": "...",                                  // Manual ad / Smart+ ad / Smart+ creative id
      "timestamp": 1701090879815,
      "ad_name": "...",
      "embed_url": "https://www.tiktok.com/player/v1/...",
      "message_material_id": "..."                     // Upgraded Smart+ creative encoded id
    },
    "short_link": {                                    // when source=short_link
      "ref": "<URL-encoded, ≤2083 chars, [A-Za-z0-9_=-] only>",
      "prefilled_message": "...",
      "prefilled_message_audit_status": "PASS"         // or REJECT (then not prefilled)
    }
  }
}
```

For Manual Ads, look up details via `/ad/get/` — note that endpoint needs separate **advertiser** authorization, not the user token.

### `im_mark_read_msg` content

```jsonc
{
  "from": "<user>", "to": "<business>",
  "unique_identifier": "...",
  "from_user": {"id": "...", "role": "personal_account"},
  "to_user":   {"id": "...", "role": "business_account"},
  "conversation_id": "...",
  "timestamp": 1701090879815,
  "read": {"last_read_timestamp": 1701090879815}       // ms; last seen message's sent time
}
```

### `im_auto_message_config_update` content

```jsonc
{
  "auto_message_id": "...",
  "auto_message_type": "WELCOME_MESSAGE|SUGGESTED_QUESTION|CHAT_PROMPT",
  "auto_message_action": "CREATE|UPDATE|DELETE|ENABLE|DISABLE",
  "timestamp": 1714430514238,                          // ms
  // exactly one of the following based on auto_message_type:
  "welcome_message": {"content": "Hi there, ..."},
  "suggested_question": {"question": "...", "answer": "..."},
  "chat_prompt": {"title": "Button label", "content": "Generated question"}
}
```

`auto_message_action` per type:
- WELCOME_MESSAGE: only `CREATE`, `DELETE`, `ENABLE`, `DISABLE` (no `UPDATE` — an update fires `DELETE` + `CREATE`, plus an `im_auto_message_audit_update`).
- SUGGESTED_QUESTION / CHAT_PROMPT: all five (`CREATE`, `UPDATE`, `DELETE`, `ENABLE`, `DISABLE`).

Requires the business to have granted `message.list.read` scope and kept it valid.

### `im_auto_message_audit_update` content

```jsonc
{
  "auto_message_id": "...",
  "auto_message_type": "WELCOME_MESSAGE|SUGGESTED_QUESTION|CHAT_PROMPT",
  "audit_status": "APPROVED",                          // or REJECTED
  "timestamp": 1714430514238
}
```

Same scope requirement as `im_auto_message_config_update`.

### `im_receive_high_intent_comment` content

```jsonc
{
  "from": "<user>", "to": "<business>",
  "unique_identifier": "...",
  "from_user": {"id": "...", "role": "personal_account"},
  "to_user":   {"id": "...", "role": "business_account"},
  "comment_id": "...",                                 // pass to direct_reply.comment_reply.comment_id
  "comment_text": "...",
  "is_follower": true,
  "timestamp": 1701090879815                           // ms
}
```

Only fires when Comment-to-Message is enabled. Reply via `/business/message/send/` using `direct_reply.reply_type=COMMENT_REPLY`; all five eligibility conditions in [direct-reply.md](direct-reply.md) must hold.

## Prerequisites for delivery (DIRECT_MESSAGE)

- Business Account must accept DMs **from everyone** in the TikTok app before authorizing your app. Otherwise webhooks only fire after the business manually accepts each message request in-app.
- Subscribe once per developer app — applies to every business that authorizes it; no per-business subscription needed.
- `im_auto_message_*` events need the `message.list.read` scope to remain granted and valid.
- `im_receive_high_intent_comment` needs Comment-to-Message enabled on the Business Account.

## BRAND_MENTION events

Fires when a user mentions (`@business_handle`) the business in a video caption or a comment. **Latency: up to 2–3 hours** (not real-time).

Subscribe: `POST /business/webhook/update/` with `event_type: "BRAND_MENTION"`. Requires the Mentions permission on your dev app.

### `brand.mention.event` envelope

```jsonc
{
  "client_key": "<app_id>",
  "event": "brand.mention.event",
  "create_time": 1732150252,                 // seconds
  "user_openid": "<mentioned business's open_id>",
  "content": "<JSON-string>"
}
```

### `brand.mention.event` content

```jsonc
{
  "type_of_event": "CREATE",                 // CREATE | EDIT | PRIVACY_CHANGE
  "mention_type": "VIDEO_MENTION",           // VIDEO_MENTION (caption) | COMMENT (in comment text)
  "video_id": "...",
  "video_create_time": 1615338610,           // seconds
  "open_id_of_mentioned_user": "...",        // = business_id for Mentions API
  "unique_name_of_mentioned_user": "<handle>",
  "unique_identifier": "<commenter's stable id>",
  "share_url": "https://...",
  "video_caption": "...",
  "comment_id": "0"                          // "0" when mention_type=VIDEO_MENTION
}
```

The sample envelope in TikTok's docs writes `"mention_type": "VIDEO MENTION"` (space) but the field definition lists the enum as `VIDEO_MENTION` (underscore). Code defensively — accept both.

## VIDEO events (post publishing)

Fires on lifecycle transitions for content published via `/business/video/publish/` or `/business/photo/publish/`. Subscribe: `POST /business/webhook/update/` with `event_type: "VIDEO"`. Requires TikTok Accounts > Business Content permission on the dev app.

Four distinct event names share the same envelope and the common content field `publish_id` (the `share_id` returned by the publish endpoint) plus `publish_type` (`DIRECT_PUBLISH` is the only documented value today).

### Lifecycle

| Stage | Event | When | Typical latency |
|---|---|---|---|
| 1 (one of two) | `post.publish.failed` | Format constraints violated, or source URL download couldn't complete in 1h | Non-deterministic — ≤30 min for a 1 GB file |
| 1 (one of two) | `post.publish.complete` | Upload + format checks succeeded | Same as above |
| 2 | `post.publish.publicly_available` | Moderation passed, post distributed publicly. `post_id` is now usable for insights | Usually ≤2 min after stage 1, longer with manual moderation |
| 3 (conditional) | `post.publish.no_longer_publicly_available` | Post pulled from public — subsequent moderation, or user switched it to friends-only/private | Any time after stage 2 |

**Important:** stage 1 fires `failed` **or** `complete`, never both. Stage 2 (`publicly_available`) only fires if stage 1 was `complete`. Stage 3 may fire repeatedly or never; treat it as a state-change signal, not a terminal event.

### `post.publish.failed` content

```jsonc
{
  "publish_id": "v_pub_url~v1.2345123456789123456",
  "reason": "file_format_check_failed",
  "publish_type": "DIRECT_PUBLISH"
}
```

### `post.publish.failed` reasons

| `reason` | Retry? | Notes |
|---|---|---|
| `file_format_check_failed` | ❌ no | File format doesn't meet spec |
| `duration_check_failed` | ❌ no | Video must be 3–60 s |
| `frame_rate_check_failed` | ❌ no | Video must be 23–60 FPS |
| `picture_size_check_failed` | ❌ no | Min 360p height **and** width |
| `internal` | ✅ yes | Transient server issue |
| `video_pull_failed` | ✅ if URL valid | Couldn't fetch video URL within 1 h. Check public reachability/bandwidth |
| `photo_pull_failed` | ✅ if URL valid | Same for photo |
| `auth_removed` | ❌ no | Creator revoked your app's access mid-flow |
| `spam_risk_too_many_posts` | ❌ no | >24 h rate limit hit via API — tell user to post from the TikTok app |
| `spam_risk_user_banned_from_posting` | ❌ no | Creator banned from posting |
| `spam_risk_text` | ❌ no | Description text flagged |
| `spam_risk` | ❌ not recommended | Generic spam-risk rejection (frequency + behaviour signals) |
| `publish_cancelled` | n/a | Upload/download cancelled |

### `post.publish.complete` content

```jsonc
{
  "publish_id": "v_pub_url~v1.2345123456789123456",
  "publish_type": "DIRECT_PUBLISH"
}
```

No `post_id` yet — that arrives with `post.publish.publicly_available`.

### `post.publish.publicly_available` content

```jsonc
{
  "publish_id": "v_pub_url~v1.2345123456789123456",
  "post_id": "1234567891234567891",          // use as video_ids filter on /business/video/list/
  "publish_type": "DIRECT_PUBLISH"
}
```

This is the first event where `post_id` exists. Use it for insights/comments queries.

### `post.publish.no_longer_publicly_available` content

```jsonc
{
  "publish_id": "v_pub_url~v1.2345123456789123456",
  "post_id": "1234567891234567891",
  "publish_type": "DIRECT_PUBLISH"
}
```

### Webhook events vs REST `publish/status/` status enum

The push and pull APIs don't have a 1:1 mapping — the webhook surfaces more states:

| REST `status` | Webhook event |
|---|---|
| `PROCESSING_DOWNLOAD` | (no direct event — pre-stage-1 in-flight) |
| `FAILED` | `post.publish.failed` |
| `PUBLISH_COMPLETE` | `post.publish.complete` — note REST may report this before moderation finishes; `post_ids[]` can take up to 3 min to appear, aligning with `post.publish.publicly_available` |
| `SEND_TO_USER_INBOX` | (no event — draft-to-inbox flow not covered by these webhooks) |
| n/a | `post.publish.publicly_available` (webhook-only) |
| n/a | `post.publish.no_longer_publicly_available` (webhook-only) |

If you need to detect a post being removed from public view after the fact, the webhook is the only source — REST `publish/status/` won't tell you.

## COMMENT events (comment lifecycle)

Event name: **`comment.update`**. Fires within **5 minutes** when a comment or reply is created, deleted, or has its visibility changed on any photo post or public video post on the owned account. Applies to posts published via `/business/video/publish/`, `/business/photo/publish/`, **or** manually via the TikTok app.

Subscribe:

```bash
# All posts
curl -X POST .../business/webhook/update/ -H 'Content-Type: application/json' \
  -d '{"app_id":"...","secret":"...","event_type":"COMMENT","callback_url":"..."}'

# Specific posts only
curl -X POST .../business/webhook/update/ -H 'Content-Type: application/json' \
  -d '{"app_id":"...","secret":"...","event_type":"COMMENT","callback_url":"...","item_list":["<video_id>","..."]}'
```

Permissions: TikTok Accounts > Business Comment on the dev app, **plus** the account owner must have granted the `comment.list` scope ("Read the comments and replies of your in-app content") and kept it valid. Lapsed authorization → no events.

### `comment.update` envelope

```jsonc
{
  "client_key": "<app_id>",
  "event": "comment.update",
  "create_time": 1615338610,                 // seconds
  "user_openid": "<business_id>",
  "content": "<JSON-string>"
}
```

### `comment.update` content

```jsonc
{
  "comment_id": 7247303576418566913,         // typed as number in docs — exceeds JS safe int; parse as string/bigint
  "video_id": 7203946942097902849,           // same caveat
  "parent_comment_id": 7235861947622916866,  // only present when comment_type=reply
  "comment_type": "reply",                   // "comment" | "reply"
  "comment_action": "delete",                // see enum below
  "unique_identifier": "...",                // stable across APIs
  "timestamp": 1687394416109                 // ms (despite docs labeling it Unix date-time)
}
```

`comment_action` enum:

| Value | Meaning |
|---|---|
| `insert` | Comment/reply created |
| `delete` | Comment/reply deleted |
| `set_to_hidden` | Hidden by owner or moderation |
| `set_to_friends_only` | Restricted to friends |
| `set_to_public` | Made publicly visible (from hidden or friends-only) |

The payload **does not include the comment text** — for `insert` events, call `GET /business/comment/list/?comment_ids=[<comment_id>]` to fetch body, author, likes, etc. (see [comments.md](comments.md)). For `delete`, the comment is gone — the webhook is the only record.

**JSON number precision:** `comment_id`, `video_id`, and `parent_comment_id` are documented as `number` and TikTok serializes them as bare numerics (e.g. `7247303576418566913`). They exceed `Number.MAX_SAFE_INTEGER` (2^53−1), so in Node/JS use `JSON.parse` with a reviver that converts those keys to `BigInt` or `string`, or use a library like `json-bigint`. Naïve `JSON.parse` will silently lose precision and produce wrong IDs.
