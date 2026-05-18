# Direct Reply (Comment-to-Message)

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Direct-Reply>

The Comment-to-Message feature lets a Business Account proactively send a DM in response to a "high-intent" comment (one expressing purchase intent or seeking info) on its own video. Replies are sent via `/business/message/send/` with a `direct_reply` body instead of `recipient_type`/`recipient`.

## Eligibility

- Business Account registered in **Vietnam, Indonesia, or Thailand**.
- Account owner **18+**.
- Account is a Registered Business Account, OR has run TikTok Messaging Ads.
- Messaging permissions "Potential connections" + "Other on TikTok" set to "Requests".

Once enabled, the account can only reply to commenters registered in **APAC, LATAM, or METAP** regions.

## POST `/business/message/direct_reply/update/`

Toggle the feature on/off for the account.

```json
{"business_id":"...","direct_reply_type":"COMMENT_TO_MESSAGE","operation_status":"ENABLE"}  // or DISABLE
```

Response `data` is an empty object `{}`.

## GET `/business/message/direct_reply/get/`

Query: `business_id`, `direct_reply_type=COMMENT_TO_MESSAGE`.

Returns `operation_status: ENABLE | DISABLE`.

## Sending a comment reply

Once Comment-to-Message is enabled, the TikTok system fires `im_receive_high_intent_comment` webhook events (see [webhook-events.md](webhook-events.md)) with a `comment_id`. Reply via `/business/message/send/`:

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

**All five conditions must hold for the reply to succeed:**

1. Comment is a **first-level** comment (not a reply) on the Business Account's own video.
2. Reply sent **within 48 h** of the comment being posted.
3. Comment has **no prior reply** (via app or API).
4. **No DM activity** between the commenter and the Business Account in the past 24 h.
5. Commenter is **18+**.

If any condition fails, the reply is rejected — the account is otherwise restricted from initiating DMs.
