# Videos

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Videos>

Lists owned-account posts (video, photo, text) with reach + engagement + analytics. Source of `video_id`/`item_id` used by comment endpoints and `share_post.item_id` in `/business/message/send/`.

## GET `/business/video/list/`

Query params:

| Field | Required | Notes |
|---|---|---|
| `business_id` | yes | `open_id` from token response |
| `fields` | no | JSON-array string. **Must include `item_id`** when requesting other fields. Default `["item_id"]` |
| `filters` | no | JSON-encoded object: `{"video_ids": ["..."], "ad_post_only": false}`. `ad_post_only` only valid when `video_ids` is also passed |
| `cursor` | no | Default is **current Unix ms timestamp** — pass any UTC ms to fetch posts before that moment |
| `max_count` | no | 1–20, default 10. May return fewer due to trust & safety filtering |

## Required scopes

- `video.list` — basic fields: `item_id`, `media_type`, `is_ad`, `thumbnail_url`, `share_url`, `embed_url`, `caption`, `video_duration`, `likes`, `comments`, `shares`, `favorites`, `video_views`, `reach`, `create_time`.
- `video.insights` — analytics fields: `total_time_watched`, `average_time_watched`, `full_video_watched_rate`, `new_followers`, `profile_views`, `website_clicks`, `phone_number_clicks`, `lead_submissions`, `app_download_clicks`, `email_clicks`, `address_clicks`, `video_view_retention`, `impression_sources`, `audience_genders`, `audience_countries`, `audience_cities`, `audience_types`, `engagement_likes`.

Check granted scopes via `POST /tt_user/token_info/get/` (see [authentication.md](authentication.md)).

## Gotchas

- **365-day data lifetime.** Posts stop updating their data 365 days after publication.
- **24–48 h latency** on most engagement and analytics fields. `item_id`, `media_type`, `is_ad`, `thumbnail_url`, `share_url`, `embed_url`, `caption`, `create_time` are real-time. Everything else lags.
- **7-day-inactivity gap.** `reach`, `full_video_watched_rate`, `total_time_watched`, `average_time_watched`, `impression_sources`, `audience_countries` are **unavailable** for videos with no view/like/comment/share activity in the past 7 days. To populate, interact with the video and retry after 24–48 h.
- **Silent filtering.** Posts may be omitted from results due to violations (e.g. music copyright) — don't assume the list is exhaustive.
- **Registered Business Accounts only** for `profile_views`, `website_clicks`, `phone_number_clicks`, `lead_submissions`, `app_download_clicks`, `email_clicks`, `address_clicks`.
- **Cursor defaults to now.** If you omit `cursor`, you get the most recent posts. Pass a custom Unix-ms timestamp to walk backwards from a specific moment in history.

## Response shape (summary)

`data.videos[]` — array of post objects. Each post has the fields listed under "Required scopes" above. Arrays like `audience_countries`, `audience_cities`, `impression_sources`, `video_view_retention`, `engagement_likes` are present when the corresponding metric is available.

For the full field-by-field schema with examples see the **[live OpenAPI docs](https://tiktok-business-api-docs.pages.dev/#tag/Videos)**.

## Distinguishing post types

- `media_type` = `VIDEO` for video posts, `PHOTO` for photo or text posts.
- `is_ad` = `true` if the post is being used in a Spark Ad (Push or Pull).
