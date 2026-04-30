# Add Telegram Channel to Cashier Bot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Telegram as a second messaging channel for the Zakheus receipt-scanning bot, alongside the existing WhatsApp channel.

**Architecture:** Configuration-only change — OpenClaw has built-in Telegram support. We add the `telegram` channel block to `openclaw.json`, set up a bot via BotFather, add `TELEGRAM_BOT_TOKEN` to env, update `SOUL.md` to be channel-agnostic, and expose the Telegram webhook port in Docker.

**Tech Stack:** OpenClaw gateway (Docker), Telegram Bot API (via BotFather)

---

## File Structure

- Modify: `openclaw.json` — add `channels.telegram` config block
- Modify: `.env` / `.env.example` — add `TELEGRAM_BOT_TOKEN`
- Modify: `docker-compose.yml` — pass `TELEGRAM_BOT_TOKEN` env var into container
- Modify: `workspace/SOUL.md` — remove WhatsApp-specific language, make channel-agnostic

No new files needed. No plugin changes — the `generate_payment_excel` tool and `AGENTS.md` instructions are already channel-agnostic.

---

### Task 1: Create Telegram Bot via BotFather

This is a manual step the user performs in Telegram.

- [ ] **Step 1: Create bot**

Open Telegram, search for `@BotFather`, send `/newbot`.
- Bot name: `Zakheus Kasir` (or similar)
- Bot username: `zakheus_kasir_bot` (must end in `_bot`)

- [ ] **Step 2: Save the bot token**

BotFather returns a token like `123456789:ABCDEFghijklmnopqrstuvwxyz`. Copy it.

- [ ] **Step 3: Set bot description**

In BotFather, send `/setdescription` and set:
> Asisten pencatatan keuangan PT. WIKA NIAGA SUKSES. Kirim foto bukti transaksi untuk dikonversi ke file Excel format Accurate.

- [ ] **Step 4: Enable group privacy mode (optional)**

If the bot will only be used in DMs (not groups), no action needed — default privacy mode is fine.

---

### Task 2: Add Telegram Bot Token to Environment

**Files:**
- Modify: `.env`
- Modify: `.env.example`

- [ ] **Step 1: Add token to `.env.example`**

```bash
# Telegram Bot Token (from @BotFather)
TELEGRAM_BOT_TOKEN=your-bot-token-here
```

- [ ] **Step 2: Add actual token to `.env`**

```bash
# Telegram Bot Token (from @BotFather)
TELEGRAM_BOT_TOKEN=<paste-real-token-from-step-1>
```

- [ ] **Step 3: Commit**

```bash
git add .env.example
git commit -m "feat: add TELEGRAM_BOT_TOKEN to env example"
```

Note: Do NOT commit `.env` — it contains secrets.

---

### Task 3: Pass Token into Docker Container

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Add TELEGRAM_BOT_TOKEN to environment**

In `docker-compose.yml`, add the env var to the `openclaw-gateway` service:

```yaml
    environment:
      - NODE_ENV=development
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
```

- [ ] **Step 2: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: pass TELEGRAM_BOT_TOKEN into openclaw container"
```

---

### Task 4: Add Telegram Channel Config to openclaw.json

**Files:**
- Modify: `openclaw.json`

- [ ] **Step 1: Add telegram channel block**

Add `telegram` as a sibling to the existing `whatsapp` entry under `channels`:

```json
"telegram": {
  "enabled": true,
  "dmPolicy": "allowlist",
  "allowFrom": [],
  "mediaMaxMb": 50,
  "streaming": "partial"
}
```

Notes:
- `botToken` is intentionally omitted — OpenClaw reads it from `TELEGRAM_BOT_TOKEN` env var
- `allowFrom` starts empty — the user will add Telegram numeric user IDs after setup
- `dmPolicy: "allowlist"` matches the WhatsApp security posture (only approved users)
- `mediaMaxMb: 50` matches WhatsApp config for consistency

- [ ] **Step 2: Commit**

```bash
git add openclaw.json
git commit -m "feat: add Telegram channel config to openclaw.json"
```

---

### Task 5: Make SOUL.md Channel-Agnostic

**Files:**
- Modify: `workspace/SOUL.md`

- [ ] **Step 1: Update SOUL.md**

Change:
```markdown
- Mengirim file Excel kembali via WhatsApp
```

To:
```markdown
- Mengirim file Excel kembali ke pengguna
```

This makes the agent description channel-agnostic since the same agent handles both WhatsApp and Telegram.

- [ ] **Step 2: Commit**

```bash
git add workspace/SOUL.md
git commit -m "feat: make SOUL.md channel-agnostic for multi-channel support"
```

---

### Task 6: Restart and Test

- [ ] **Step 1: Restart the gateway**

```bash
docker compose down && docker compose up -d
```

- [ ] **Step 2: Check logs for Telegram connection**

```bash
docker logs kasir-gateway 2>&1 | grep -i telegram
```

Expected: log lines showing Telegram bot connected / polling started.

- [ ] **Step 3: Find your Telegram user ID**

Send a message to the bot on Telegram. Check the gateway logs for the rejected message — it will show your numeric user ID.

```bash
docker logs kasir-gateway 2>&1 | grep -i "allowFrom\|denied\|unauthorized"
```

- [ ] **Step 4: Add your user ID to allowFrom**

Edit `openclaw.json` and add your numeric Telegram user ID to `channels.telegram.allowFrom`:

```json
"allowFrom": ["YOUR_NUMERIC_ID"]
```

- [ ] **Step 5: Restart gateway again**

```bash
docker compose down && docker compose up -d
```

- [ ] **Step 6: End-to-end test**

Send a receipt photo to the bot via Telegram. Verify:
1. Bot acknowledges the photo and extracts data
2. Classification matches expected accounts
3. Typing "selesai" triggers Excel generation
4. Bot sends back the `.xlsx` file as an attachment

---

## Verification Checklist

1. Gateway starts without errors, both WhatsApp and Telegram channels active in logs
2. Sending a receipt photo via Telegram produces the same extraction quality as WhatsApp
3. Multi-photo flow works (send multiple photos, then "selesai")
4. Excel file is delivered back as attachment via Telegram
5. WhatsApp channel still works (regression check)
6. Unauthorized Telegram users are rejected (allowlist enforcement)
