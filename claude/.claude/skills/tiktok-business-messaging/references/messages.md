# Messages

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Messages>

Covers sending direct messages, message templates, sender actions, and managing automatic messages (welcome / suggested questions / chat prompts).

## POST `/business/message/send/`

Headers: `Access-Token: <token>`, `Content-Type: application/json`.

Common body fields:

| Field | Required? | Notes |
|---|---|---|
| `business_id` | always | `open_id` from token response |
| `recipient_type` | when not `direct_reply` | only `CONVERSATION` |
| `recipient` | when not `direct_reply` | `conversation_id` |
| `message_type` | always | `TEXT` \| `IMAGE` \| `SHARE_POST` \| `TEMPLATE` \| `SENDER_ACTION` |
| `text.body` | when `TEXT` | ≤ 6000 chars (incl spaces/emoji) |
| `image.media_id` | when `IMAGE` | from `media/upload/` (see [media.md](media.md)) |
| `share_post.item_id` | when `SHARE_POST` | post ID from `/business/video/list/` (see [videos.md](videos.md)); **only your own posts** |
| `template` | when `TEMPLATE` | see below |
| `sender_action` | when `SENDER_ACTION` | `TYPING` (5s indicator) \| `MARK_READ` |
| `referenced_message_info.referenced_message_id` | for quoted reply | combine with `message_type=TEXT` only |
| `direct_reply` | for comment reply | see [direct-reply.md](direct-reply.md) |

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
- Self-defined `id` ≤ 40 chars — surfaces in webhook `reply_source_payload.reply_source_unique_id` so you can attribute which button was clicked.

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

## Auto-messages (welcome / suggested questions / chat prompts)

Three feature types — each has its own per-account cap:

| `auto_message_type` | What it is | Max per account |
|---|---|---|
| `WELCOME_MESSAGE` | Sent automatically when a user starts a conversation | **1** |
| `SUGGESTED_QUESTION` | FAQ chips at the start of a chat; tapping one sends a preset answer | **3** |
| `CHAT_PROMPT` | Buttons above the input box; tapping generates a conversation starter | **6** |

### Lifecycle

Each message has two independent states:
- **`audit_status`**: `REVIEWING` (seconds to ~2–3 h) → `APPROVED` or `REJECTED`. A `REJECTED` message can't be updated — fix and recreate.
- **`operation_status`** (account-wide, per type): `ENABLE` or `DISABLE`. A message must be both `APPROVED` *and* the feature `ENABLE`d to be served.

### POST `/business/message/auto_message/status/update/`

Turn a feature on or off for the account.

Body: `business_id`, `auto_message_type`, `operation_status` (`ENABLE` | `DISABLE`).

**Destructive on enable:** turning on `SUGGESTED_QUESTION` or `CHAT_PROMPT` *disables every existing item of that type*. Recreate them afterwards.

### POST `/business/message/auto_message/create/`

Create one welcome message, suggested question, or chat prompt per call. Call multiple times to add more.

Body: `business_id`, `auto_message_type`, and **one** of:
- `welcome_message.content` — max **250** chars. Supports `\n` line breaks.
- `suggested_question.question` (max **80**) + `.answer` (max **200**).
- `chat_prompt.title` (max **18**, button label) + `.content` (max **150**, generated question).

Duplicates within a type are rejected. Chat prompts are ordered by creation time (earliest first) — use `auto_message/sort/` to reorder.

Response: `data.auto_message.auto_message_id`.

### POST `/business/message/auto_message/update/`

Replace content of an existing message. Body matches `create` plus `auto_message_id`.

**Cannot update a message with `audit_status=REVIEWING`** — check via `auto_message/get/` first.

### GET `/business/message/auto_message/get/`

List automatic messages for an account.

Query: `business_id`, `auto_message_type`, optional `auto_message_id` (filter to one).

Response `data`: `business_id`, `operation_status`, `auto_messages[]` with `auto_message_id`, `auto_message_type`, `audit_status`, plus the type-specific object (`welcome_message` / `suggested_question` / `chat_prompt`).

**TikTok docs bug:** the `CHAT_PROMPT` response example sometimes wraps content in `suggested_question` instead of `chat_prompt`. Handle both keys in client code.

**Default welcome:** if `WELCOME_MESSAGE` is enabled for the first time without a custom message, TikTok sets a default using the `{{display_name}}` template variable.

### POST `/business/message/auto_message/sort/`

Reorder chat prompts. **Only `CHAT_PROMPT` is sortable** — welcome and suggested questions can't be reordered via this endpoint.

Body: `business_id`, `auto_message_type=CHAT_PROMPT`, `auto_message_ids[]` — **all** chat prompt IDs for the account in the desired display order (index 0 = leftmost).
