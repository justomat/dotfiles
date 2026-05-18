# Comments

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Comments>

Read and reply to comments on owned videos. Companion to the `comment.update` webhook (see [webhook-events.md](webhook-events.md)).

## GET `/business/comment/list/`

Headers: `Access-Token`.

Query params:

| Field | Required | Notes |
|---|---|---|
| `business_id` | yes | `open_id` from token response |
| `video_id` | yes | from `/business/video/list/` (see [videos.md](videos.md)) |
| `comment_ids` | no | JSON-array string, up to 30, to filter specific comments/replies |
| `include_replies` | no | `true` returns up to 3 replies per top-level comment (smart-sorted). For all replies use `/business/comment/reply/list/` |
| `status` | no | `PUBLIC` \| `ALL` (default `ALL`, includes owner-hidden + system-moderated) |
| `sort_field` | no | `likes` \| `replies` \| `create_time` (default random) |
| `sort_order` | no | `asc` \| `desc` \| `smart` (default `smart`) |
| `cursor` | no | from previous response when `has_more` |
| `max_count` | no | 1–30, default 20 — may return fewer even when `has_more=true` due to trust & safety filtering |

**v1.2 → v1.3 migration:** path changed `/business/comments/list/` → `/business/comment/list/`, method `POST` → `GET`, new params `comment_ids` + `include_replies`, new response fields `parent_comment_id`, `reply_list[]`, `unique_identifier`, `display_name`, `image_url`.

**Beyond the first 500 comments** the endpoint switches to reverse-sort by likes and does **not dedupe** — pagination past 500 may return duplicates.

Response `data`:
- `comments[]` — each comment has:
  - `comment_id`, `video_id`, `create_time` (string, Unix seconds), `text`.
  - `likes`, `replies` (counts), `liked` (by video owner), `pinned`, `owner` (was it the video owner), `status` (`PUBLIC` | `HIDDEN`).
  - User: `username`, `display_name`, `profile_image` (temp URL, see `x-expires`), `unique_identifier` (stable cross-API), `user_id` (**deprecated** — prefer `unique_identifier`).
  - `parent_comment_id` — returned **only for replies**. Use its presence to distinguish replies from top-level comments.
  - `image_url` — present when the comment is an image. URL does not expire.
  - `reply_list[]` — present only on top-level comments when `include_replies=true`, max 3 entries, each with the same shape as a comment (plus `parent_comment_id`).
- `cursor`, `has_more`.

## POST `/business/comment/reply/create/`

Reply to a comment on an owned (or others') video.

Headers: `Access-Token`, `Content-Type: application/json`.

Body:

| Field | Required | Notes |
|---|---|---|
| `business_id` | yes | `open_id` |
| `video_id` | yes | from `/business/video/list/` (`item_id`) |
| `comment_id` | yes | parent comment to reply to |
| `text` | conditional | required if no `image_uri`; **≤ 150 chars** UTF-8 |
| `image_uri` | conditional | required if no `text`; obtain from `/business/comment/image/upload/` |
| `image_width` | conditional | required with `image_uri` (from upload response) |
| `image_height` | conditional | required with `image_uri` (from upload response) |
| `reply_image_url` | no | publicly accessible HTTPS image URL (alternative to `image_uri`). Constraints: 1080×1920 or 1920×1080 max, 360×360 min, ≤ 20 MB, JPG/JPEG/WebP/PNG. **URL host must be a verified URL property** on the dev app |

Response `data`: `comment_id` (the new reply), `parent_comment_id`, `video_id`, `create_time` (Unix seconds, string), `text` (when text reply) or `image_url` (when image reply — non-expiring), `unique_identifier`, `user_id` (deprecated).

**Spam guard:** posting many similar-content replies in a short window can get them silently flagged as spam and hidden — in which case you won't even receive the `comment.update` event with `comment_action=set_to_public`. Throttle and vary content.

## POST `/business/comment/image/upload/`

Upload an image for use in a comment reply.

Multipart form. Headers: `Access-Token`, `Content-Type: multipart/form-data`.

Form fields: `business_id`, `image_file` (JPG / JPEG / WebP / PNG).

Constraints:
- Max size: **5 MB**
- Max resolution: **1080×1920** or **1920×1080**
- Min resolution: **360×360**

Response `data`: `image_uri`, `width`, `height`. Pass these to `comment/reply/create/` as `image_uri`, `image_width`, `image_height`.

## GET `/business/comment/reply/list/`

All replies to a specific comment on an owned video — use this instead of `comment/list/?include_replies=true` when you need more than the 3-per-comment cap.

Query: `business_id`, `video_id`, `comment_id` (all required). Optional: `status` (`PUBLIC` | `ALL`, default `ALL`), `sort_field` (`likes` | `replies` | `create_time`), `sort_order` (`asc` | `desc`), `cursor` (default 0), `max_count` (1–30, default 20).

**Limitation:** does **not** support listing replies to a *hidden* comment.

Response shape mirrors `comment/list/`: `comments[]` (each entry has `parent_comment_id` populated), `cursor`, `has_more`.
