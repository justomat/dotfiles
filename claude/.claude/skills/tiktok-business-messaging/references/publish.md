# Publish

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Publish>

REST polling for the outcome of post-publishing tasks initiated via `/business/video/publish/` or `/business/photo/publish/`. The push equivalent is the `VIDEO` webhook (see [webhook-events.md](webhook-events.md) § VIDEO events).

## GET `/business/publish/status/`

Headers: `Access-Token`.

Query: `business_id`, `publish_id` (the `share_id` returned by `/video/publish/` or `/photo/publish/`).

Response `data`:

| `status` | Meaning |
|---|---|
| `PROCESSING_DOWNLOAD` | Fetching content from your URL (file-URL flow only) |
| `PUBLISH_COMPLETE` | Moderation passed, post is live |
| `FAILED` | Terminal failure |
| `SEND_TO_USER_INBOX` | Draft uploaded; notification sent to creator's inbox (draft-publishing flow) |

- `post_ids[]` — present **only when `status=PUBLISH_COMPLETE`** and the posts are publicly viewable. May take **up to 3 minutes** to appear after status flips. Retry if absent. Feed these to `/business/video/list/`'s `video_ids` filter to read metrics.
- `reason` — present only when `status=FAILED`. Examples: `frame_rate_check_failed`, `duration_check_failed`, `spam_risk`, `auth_removed`. See the failure-reasons table in [webhook-events.md](webhook-events.md) § VIDEO events for the full list with retryability.

## Webhook vs polling

Use the `VIDEO` webhook when you need:
- `post.publish.publicly_available` (moderation cleared, `post_id` available) — **webhook-only**.
- `post.publish.no_longer_publicly_available` (post pulled from public view) — **webhook-only**.

This polling endpoint can only tell you whether upload+format checks passed (`PUBLISH_COMPLETE`) or failed (`FAILED`). Post-publication state transitions are only delivered via webhook.
