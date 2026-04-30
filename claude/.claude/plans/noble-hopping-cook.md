# WhatsApp Receipt-to-Excel Bot — Implementation Plan

## Context

PT. WIKA NIAGA SUKSES needs to automate their manual receipt-to-Accurate workflow. Team members photograph payment receipts and send them via WhatsApp. Currently these are manually entered into Accurate accounting as "Other Payment" entries.

This plan builds a WhatsApp bot on OpenClaw (self-hosted AI gateway) with a custom plugin that:
1. Receives receipt photos via WhatsApp
2. Extracts data using local Ollama vision (llama3.2-vision)
3. Auto-classifies expenses against the chart of accounts
4. Generates an Excel file in Accurate's import format
5. Sends the Excel back via WhatsApp

Full spec: `docs/superpowers/specs/2026-04-12-whatsapp-receipt-bot-design.md`

## Approach: Custom OpenClaw Plugin + Agent Prompt

### Step 1: Scaffold the plugin project

Create `cashier-plugin/` with:
- `package.json` (with `openclaw` metadata, `exceljs` + `@sinclair/typebox` deps)
- `openclaw.plugin.json` (manifest)
- `tsconfig.json`
- `src/index.ts` (plugin entry)
- `src/generate-excel.ts` (Excel generation logic)

### Step 2: Implement `generate_payment_excel` tool

In `src/generate-excel.ts`:
- Accept structured JSON (paidFrom, date, payee, lineItems with accountNo/accountName/amount/memo)
- Generate `.xlsx` using `exceljs` matching the Accurate "Other Payment" format:
  - Row 1: headers (Paid From, Voucher No., Cek Kosong, Cheque No., Date, Payee, Amount)
  - Row 2: values (Amount = sum of line items)
  - Row 3: blank
  - Row 4: line item headers (Account No., Account Name, Amount, Memo)
  - Row 5+: line items
- Write to temp file, return path

In `src/index.ts`:
- Register the tool via `api.registerTool()` with TypeBox schema

### Step 3: Write the agent definition

Create workspace files:
- `SOUL.md` — Kasir personality, Bahasa Indonesia, receipt-focused
- `AGENTS.md` — system prompt with:
  - Full chart of accounts table
  - Classification rules (keyword → account mapping)
  - Multi-photo flow instructions
  - Output format rules (account number format)

### Step 4: Configure the gateway

Create/update `openclaw.json` with:
- Ollama provider config (host.docker.internal for Docker dev, 127.0.0.1 for prod)
- WhatsApp channel config (allowlist policy)
- Tool allowlist for generate_payment_excel
- Agent workspace path

### Step 5: Docker dev setup

- `docker-compose.yml` for OpenClaw gateway
- Volume mount for plugin source (hot reload during dev)
- Network config to reach host Ollama

### Step 6: Test end-to-end

1. Unit test: generate-excel with known JSON input
2. Plugin test: register tool, call with mock data
3. E2E: send receipt photo via WhatsApp, verify Excel output
4. Multi-photo: send batch, confirm, verify consolidated Excel
5. Classification: compare against reference data in `d06dcabe-f1ed-409e-a579-5a14bbb3a2e7.csv`

## Critical Files

- `cashier-plugin/src/index.ts` — plugin entry
- `cashier-plugin/src/generate-excel.ts` — Excel generation
- `cashier-plugin/package.json` — dependencies and openclaw metadata
- `cashier-plugin/openclaw.plugin.json` — plugin manifest
- Workspace `AGENTS.md` — agent behavior and chart of accounts
- Workspace `SOUL.md` — agent personality
- `openclaw.json` — gateway configuration
- `docker-compose.yml` — dev environment

## Verification

1. `npm test` in cashier-plugin/ passes
2. Plugin installs cleanly: `openclaw plugins install ./cashier-plugin`
3. Send a test receipt photo via WhatsApp → receive correct Excel back
4. Excel matches the format in `d06dcabe-f1ed-409e-a579-5a14bbb3a2e7.csv`
5. Multi-photo flow works with confirmation prompt
