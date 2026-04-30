# Convert wika to a Moon + pnpm monorepo and absorb wika-web

## Context

Today `wika/` is an Ansible-only repo for the self-hosted mail stack and `wika-web/` is a separate Next.js static-export site (Cloudflare Workers) with its own GitHub remote. They're developed together but live apart, which fragments history, tooling, and CI.

Goal: make `wika/` a monorepo containing both, preserving wika-web's git history, with pnpm workspaces managing JS deps and Moon orchestrating tasks across TypeScript and Ansible.

Decisions (confirmed with user):
- Web app location: `apps/wikaniagasukses.com/`
- History: `git subtree add` (preserves commits)
- Tooling: **Moon** + **pnpm workspaces**
- Pre-merge: commit WIP in both repos first via the commit skill

## Target layout

```
wika/
  .moon/
    workspace.yml
    toolchain.yml
  apps/
    wikaniagasukses.com/          # Next.js site (was wika-web)
      moon.yml
      package.json
      src/ public/ scripts/ ...
  infra/                          # Ansible (unchanged)
    moon.yml
  docs/
  pnpm-workspace.yaml
  package.json                    # root, private
  .gitignore
  CLAUDE.md
```

## Execution steps

### 1. Clean working trees (both repos)

Both repos have uncommitted work. Commit in each via the commit skill before any restructuring.

- `wika`: WIP includes `infra/dns.yml`, new `cloudflare_dns` + `stalwart-principals` roles, gateway/primary playbook edits, secrets/gitignore/CLAUDE.md updates. Plus two untracked docs and a session log.
- `wika-web`: no uncommitted tracked changes observed — verify with `git status` and commit if anything surfaces. Ensure `.next/`, `out/`, `.wrangler/`, `node_modules/`, and `session-ses_261b.md` stay untracked (already in `.gitignore`).

Action: invoke `commit-commands:commit` skill in each repo.

### 2. Bring wika-web in via subtree

Run from inside `/Users/ger/src/justomat/wika`:

```bash
git remote add wika-web-src /Users/ger/src/justomat/wika-web
git fetch wika-web-src
git subtree add --prefix=apps/wikaniagasukses.com wika-web-src main --squash=false
git remote remove wika-web-src
```

Keep full history (no squash) — user wanted preservation.

### 3. Clean up imported artifacts

After subtree import, inside `apps/wikaniagasukses.com/`:
- Delete `node_modules/`, `.next/`, `out/`, `.wrangler/` (will regenerate)
- Delete `package-lock.json` (pnpm will produce a single root `pnpm-lock.yaml`)
- Delete `.DS_Store` files
- Keep `session-ses_261b.md`? It's currently untracked in wika-web; exclude from subtree by cleaning after import.

Move `.gitignore` rules up: the imported `apps/wikaniagasukses.com/.gitignore` stays local to the subdir (that's fine with git).

### 4. Install pnpm workspace at root

Create `/Users/ger/src/justomat/wika/pnpm-workspace.yaml`:

```yaml
packages:
  - "apps/*"
```

Create `/Users/ger/src/justomat/wika/package.json`:

```json
{
  "name": "wika",
  "private": true,
  "packageManager": "pnpm@9.15.0"
}
```

(Version pinned via `packageManager` field so Moon's proto toolchain picks it up.)

Run `pnpm install` at root → produces root `pnpm-lock.yaml`, hoists what it can into root `node_modules`.

Verify: `cd apps/wikaniagasukses.com && pnpm run build` still works end-to-end (`next build` + `fix-export-lang.mjs`).

### 5. Initialize Moon

Install via proto or npm (`npm install -g @moonrepo/cli` or use `proto install moon`). Then from wika root:

```bash
moon init
```

Edit the generated files:

**`.moon/toolchain.yml`**

```yaml
node:
  version: "22.11.0"           # match Next.js 16 requirements
  packageManager: "pnpm"
  pnpm:
    version: "9.15.0"
```

Ansible is not a first-class Moon toolchain — it runs as generic system tasks. Ensure control node has `ansible` on PATH; no Moon toolchain entry needed.

**`.moon/workspace.yml`**

```yaml
projects:
  web: "apps/wikaniagasukses.com"
  infra: "infra"

vcs:
  manager: "git"
  defaultBranch: "main"
```

**`apps/wikaniagasukses.com/moon.yml`**

```yaml
type: "application"
language: "typescript"
platform: "node"

tasks:
  dev:
    command: "next dev"
    options:
      cache: false
      runInCI: false
  build:
    command: "pnpm run build"      # next build + fix-export-lang.mjs
    inputs:
      - "src/**/*"
      - "public/**/*"
      - "scripts/**/*"
      - "next.config.ts"
      - "tsconfig.json"
      - "package.json"
    outputs:
      - "out"
      - ".next"
  test:
    command: "vitest run"
    inputs:
      - "src/**/*"
      - "vitest.config.ts"
  deploy:
    command: "wrangler deploy"
    deps: ["~:build"]
    options:
      cache: false
      runInCI: false
```

**`infra/moon.yml`**

```yaml
type: "configuration"
language: "bash"

tasks:
  deploy-gateway:
    command: "ansible-playbook -i infra/inventory.ini infra/gateway.yml"
    options:
      cache: false
      runInCI: false
      runFromWorkspaceRoot: true
  deploy-primary:
    command: "ansible-playbook -i infra/inventory.ini infra/primary.yml"
    options:
      cache: false
      runInCI: false
      runFromWorkspaceRoot: true
  dns:
    command: "ansible-playbook -i infra/inventory.ini infra/dns.yml"
    options:
      cache: false
      runInCI: false
      runFromWorkspaceRoot: true
  show-admin-password:
    command: "ansible-playbook -i infra/inventory.ini infra/primary.yml --tags show-admin-password"
    options:
      cache: false
      runInCI: false
      runFromWorkspaceRoot: true
```

Ansible tasks opt out of caching — they have side effects (SSH, remote state) that shouldn't be skipped based on input hash.

### 6. Reconcile root `.gitignore`

Merge web-specific ignores into root `.gitignore`, scoped so they cover the monorepo:

```
# Existing (wika)
.worktrees/
infra/.admin_secrets/

# Node / pnpm
node_modules/
.pnpm-store/
pnpm-debug.log

# Next.js / Cloudflare (scoped to apps)
apps/*/.next/
apps/*/out/
apps/*/.wrangler/

# Moon
.moon/cache/
.moon/docker/

# OS
.DS_Store
```

The per-app `apps/wikaniagasukses.com/.gitignore` can stay (harmless redundancy) or be trimmed.

### 7. Update CLAUDE.md

Add a section noting the new layout and the Moon entry points:

```
## Monorepo layout

- `apps/wikaniagasukses.com` — Next.js static-export site (Cloudflare Workers)
- `infra/` — Ansible playbooks for mail stack
- Managed with **Moon** + **pnpm workspaces**

## Common tasks

- `moon run web:dev` — Next dev server
- `moon run web:build` — static export
- `moon run web:test` — Vitest
- `moon run web:deploy` — wrangler deploy
- `moon run infra:deploy-gateway` / `deploy-primary` / `dns`
```

### 8. Point wika-web's GitHub remote at the monorepo

The original `wika-web` repo's remote is `git@github.com:wika-niaga-sukses/website.git`. After confirming the monorepo works, either:
- Archive that repo and push `wika` monorepo to a new remote (e.g. `wika-niaga-sukses/wika`), or
- Repurpose the `website` remote by force-pushing `wika`'s history (destructive; ask before doing).

This step is **out of scope for the initial restructure** — flag it for the user to decide after local verification.

## Critical files

- `/Users/ger/src/justomat/wika/.gitignore` — merged ignores
- `/Users/ger/src/justomat/wika/package.json` — new root
- `/Users/ger/src/justomat/wika/pnpm-workspace.yaml` — new
- `/Users/ger/src/justomat/wika/.moon/workspace.yml` — project map
- `/Users/ger/src/justomat/wika/.moon/toolchain.yml` — node/pnpm versions
- `/Users/ger/src/justomat/wika/apps/wikaniagasukses.com/moon.yml` — web tasks
- `/Users/ger/src/justomat/wika/infra/moon.yml` — ansible tasks
- `/Users/ger/src/justomat/wika/CLAUDE.md` — updated guidance

## Verification

From `/Users/ger/src/justomat/wika` after execution:

1. **History preserved**: `git log --oneline apps/wikaniagasukses.com/` shows the original wika-web commits (c03dcb0, 9c2db96, 1aaef7e, b2f6104, 045c9e2, …).
2. **pnpm install**: `pnpm install` at root succeeds; `node_modules` appears at root and/or `apps/wikaniagasukses.com/node_modules`.
3. **Web build**: `moon run web:build` completes; `apps/wikaniagasukses.com/out/index.html` exists with `lang="id"`, `apps/wikaniagasukses.com/out/en/index.html` with `lang="en"`.
4. **Web tests**: `moon run web:test` — Vitest passes (`page.test.tsx`, `not-found.test.tsx`).
5. **Web dev**: `moon run web:dev` boots Next on `http://localhost:3000`.
6. **Moon task graph**: `moon query tasks` lists `web:dev/build/test/deploy` and `infra:deploy-gateway/deploy-primary/dns/show-admin-password`.
7. **Ansible dry-run (optional)**: `moon run infra:deploy-gateway -- --check` completes without SSH errors (requires network to gateway).
8. **Repo hygiene**: `git status` clean; no leaked `node_modules/`, `.next/`, `out/`, `.wrangler/`.
