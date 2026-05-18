# Media

**Authoritative schemas:** <https://tiktok-business-api-docs.pages.dev/#tag/Media>

Upload, download, and capability checks for image/video attachments in direct messages.

## POST `/business/message/media/upload/`

Multipart form. Headers: `Access-Token`, `Content-Type: multipart/form-data`.

Form fields:
- `business_id`
- `file` — JPG or PNG, ≤ **3 MB**
- `media_type` — `IMAGE` (only supported value)

Response `data.media_id` — valid **30 days**. After expiry, re-upload to get a new ID.

## POST `/business/message/media/download/`

JSON body:
```json
{
  "business_id":"...","conversation_id":"...","message_id":"...",
  "media_id":"...","media_type":"IMAGE"   // or VIDEO
}
```

Response `data.download_url` — valid **24 hours**.

**Critical:** when GETting the `download_url`, you must include the header `x-user: <Access-Token>` or the download will fail with a 4xx error. The download URL itself looks public but is gated.

## GET `/business/message/capabilities/get/`

Query: `business_id`, `capability_types=["IMAGE_SEND"]` (JSON array string). When `IMAGE_SEND` is requested you must also pass `conversation_id` and `conversation_type` (`STRANGER`|`SINGLE`).

Response `data.capability_infos[].capability_result` boolean per `capability_type`.

**Why this exists:** image attachments are restricted to specific country pairs. Call this before attempting `media/upload/` + `send/` with `message_type=IMAGE` to avoid wasted work.
