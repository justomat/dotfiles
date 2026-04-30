# Plan: steelbandindonesia.com — Steel Strapping Catalog Site

## Context

Build a new static Next.js site at `apps/steelbandindonesia.com/` in this monorepo, focused on **steel strapping** products, using the same design language as `apps/wikaniagasukses.com/`. Goal: generate leads via WhatsApp (0816 193 6543 → `+628161936543`) and email (`sales@wikaniagasukses.com`). Deploy as a Cloudflare Workers Assets site with Git-connected auto-deploy.

Content is sourced from the existing wika `strapping` category in `apps/wikaniagasukses.com/src/data/catalog.ts` (steel/PET/PP strapping, tools, machines), narrowed/reframed to put **steel strapping** at the top. Images come from the web (royalty-free; downloaded into the new app's `public/images/`).

---

## Shape

- **Path:** `apps/steelbandindonesia.com/`
- **Moon project:** `steelband` (`apps/steelbandindonesia.com/moon.yml`)
- **pnpm workspace:** already picked up by `pnpm-workspace.yaml` glob `apps/*`
- **Framework:** Next.js 16 static export (`output: "export"`), React 19, Tailwind v4, Vitest — identical versions to wika
- **Locales:** `id` (default) + `en` (mirror wika's file-based i18n)
- **Deploy:** Cloudflare Workers Assets via Git-connected Workers Builds (dashboard setup, no CI file in repo)

---

## Files to create

### Root config (copied from wika, names adjusted)
- `apps/steelbandindonesia.com/package.json` — name `steelbandindonesia.com`, same deps as wika
- `apps/steelbandindonesia.com/next.config.ts` — `output: "export"`, `images.unoptimized: true`
- `apps/steelbandindonesia.com/tsconfig.json` — `@/*` → `./src/*`
- `apps/steelbandindonesia.com/postcss.config.mjs` — `@tailwindcss/postcss`
- `apps/steelbandindonesia.com/vitest.config.ts` — jsdom + setup
- `apps/steelbandindonesia.com/.gitignore` — mirror wika
- `apps/steelbandindonesia.com/moon.yml` — tasks `dev`, `build`, `test`, `deploy`, with explicit `inputs` cache list (same pattern as wika `moon.yml`)
- `apps/steelbandindonesia.com/wrangler.jsonc` — `name: "steelbandindonesia"`, `assets.directory: "./out"`, `not_found_handling: "404-page"`, observability enabled
- `apps/steelbandindonesia.com/scripts/fix-export-lang.mjs` — copy from wika (logic is generic)

### `src/lib/` (copy verbatim from wika)
- `i18n.ts`, `utils.ts`, `catalog.ts` (accessor layer), `static-export-lang.ts`
- Plus colocated tests: `i18n.test.ts`, `catalog.test.ts`, `static-export-lang.test.ts`

### `src/data/` (rewritten for steel strapping)
- `site.ts` — `sharedSite` with:
  - `name: "Steel Band Indonesia"` (brand surface)
  - `legalName`/footer credit: `"PT WIKA NIAGA SUKSES"` (operator)
  - `whatsappNumber: "+628161936543"`, `whatsappLabel: "0816 193 6543"`
  - `email: "sales@wikaniagasukses.com"`
  - Addresses copied from wika
  - `localizedSite.id` / `.en` tagline focused on steel strapping for heavy-duty bundling
- `catalog.ts` — categories narrowed to steel-strapping-centric set. Lift from wika's strapping entries:
  - Categories: `steel-strapping` (hero), `strapping-tools`, `strapping-machines`, `related-strapping` (PET/PP as secondary options)
  - Product families: `steel-strapping` (flagship — multiple widths/thicknesses as variants), `steel-strapping-seals`, `manual-strapping-tool`, `pneumatic-strapping-tool`, `battery-strapping-tool`, `strapping-machine`, plus secondary `pet-strapping`, `pp-strapping`
  - Reuse wika's `ProductFamily`/`Category` TypeScript shapes verbatim so `lib/catalog.ts` keeps working unchanged
- `catalog.id.ts` — Indonesian translation overlays for the above

### `src/components/` (copy from wika, minor brand tweaks)
- `site-shell.tsx`, `site-header.tsx`, `site-footer.tsx` — update logo wordmark to "Steel Band Indonesia"; footer adds "Operated by PT WIKA Niaga Sukses" line
- `hero.tsx` — reframed headline around steel strapping
- `whatsapp-cta.tsx` — copy as-is (takes `message` prop)
- `category-card.tsx`, `section-heading.tsx`, `spec-table.tsx`, `locale-switcher.tsx`, `locale-document-lang.tsx` — copy verbatim
- `ui/button.tsx`, `ui/badge.tsx`, `ui/card.tsx`, `ui/table.tsx` — copy verbatim (CVA + CSS vars)

### `src/app/` (mirror wika route tree, steel-specific copy)
- `layout.tsx`, `page.tsx` (home), `not-found.tsx`, `globals.css`
- `products/page.tsx`, `products/[categorySlug]/page.tsx`, `products/[categorySlug]/[familySlug]/page.tsx`
- `about/page.tsx`, `industries/page.tsx`, `contact/page.tsx`
- Full `en/` mirror of the above (7+ pages)
- Colocated tests matching wika coverage: `page.test.tsx`, `contact/page.test.tsx`, `not-found.test.tsx`

### `src/test/setup.ts`
- Copy from wika (imports `@testing-library/jest-dom/vitest`)

### `public/images/`
- Sourced from the web during implementation (**royalty-free only**: Unsplash, Pexels, or manufacturer press kits with permitted reuse). Download into the new app's `public/images/` — no hotlinking (static export would still work, but we want offline-resilient builds and our own CDN).
- Target set:
  - `public/images/categories/steel-strapping/hero.jpg`
  - `public/images/categories/strapping-tools/hero.jpg`
  - `public/images/categories/strapping-machines/hero.jpg`
  - `public/images/products/steel-strapping/coil.jpg`, `seal.jpg`, `in-use-packaging.jpg`, `in-use-construction.jpg`
  - `public/images/products/tools/manual-tool.jpg`, `pneumatic-tool.jpg`, `battery-tool.jpg`
  - `public/images/products/machines/arch-machine.jpg`
  - Plus 1 OG image for `app/layout.tsx` metadata
- During implementation: `WebSearch` for "steel strapping coil site:unsplash.com" / "steel banding pallet", verify license, `WebFetch` → save via `Bash` (curl/wget). If good free sources are not found for a slot, fall back to reusing wika's existing `public/images/products/strapping/*` that were lifted into the monorepo.

### Root workspace wiring
- `pnpm-workspace.yaml` — already has `apps/*`; no change
- `.moon/workspace.yml` — add `steelband: apps/steelbandindonesia.com` to the `projects` map (mirror how `web` is registered)

### Autodeploy (Cloudflare Workers Builds — dashboard-configured)
- No CI file added to the repo.
- Document setup in `apps/steelbandindonesia.com/CLAUDE.md`:
  1. In Cloudflare dashboard → Workers & Pages → steelbandindonesia worker → Settings → Builds → Connect to GitHub repo
  2. **Build command:** `corepack pnpm install --frozen-lockfile && moon run steelband:build`
  3. **Deploy command:** `npx wrangler deploy` (default)
  4. **Root directory:** `apps/steelbandindonesia.com`
  5. **Production branch:** `main`
  6. Env: `CI=true`; `NODE_VERSION` pinned matching wika
- Add `apps/steelbandindonesia.com/CLAUDE.md` documenting the above plus local commands.

---

## Key design decisions

1. **Palette parity with wika** — keep the warm beige / sage `:root` CSS variables in `globals.css` identical. Requirement was "similar design language"; diverging palettes would undermine that. Brand separation comes through copy, logo wordmark, and product imagery, not color.

2. **Reuse wika's TypeScript shapes unchanged** — so `src/lib/catalog.ts` (accessor) can be copied verbatim. No new types.

3. **No shared npm package for components** — duplicate `src/components/` and `src/lib/` into the new app. Matches wika's existing pattern (these are not yet extracted), avoids premature abstraction, and keeps each site independently deployable. Future DRY can happen in a separate refactor.

4. **WhatsApp-first lead gen** — same `createWhatsAppLink(message)` pattern from `site.ts`. Hero CTA, product-family CTA, contact-page CTA all deep-link to wa.me with pre-filled Indonesian/English messages. Email shown in footer + contact page. **No contact form** (matches wika and avoids needing server-side form handling on a static export).

5. **Data lifted, not imported** — copy relevant `strapping` entries from `apps/wikaniagasukses.com/src/data/catalog.ts` into the new app's `catalog.ts`. Keeps apps decoupled; future edits to one don't ripple.

---

## Existing functions/files to reference and reuse (copy patterns from)

- `apps/wikaniagasukses.com/src/lib/i18n.ts` — `localizePath`, `stripLocaleFromPath`, `getLocaleSwitchPath`
- `apps/wikaniagasukses.com/src/lib/catalog.ts` — accessor pattern for locale-aware catalog
- `apps/wikaniagasukses.com/src/lib/utils.ts` — `cn()` helper
- `apps/wikaniagasukses.com/src/data/site.ts` — `sharedSite`, `localizedSite`, `getSite`, `createWhatsAppLink`
- `apps/wikaniagasukses.com/src/data/catalog.ts` — `strapping` category + its product families (source of steel-strapping entries)
- `apps/wikaniagasukses.com/src/components/whatsapp-cta.tsx` — reusable WhatsApp CTA
- `apps/wikaniagasukses.com/src/components/ui/button.tsx` — CVA variants
- `apps/wikaniagasukses.com/scripts/fix-export-lang.mjs` — post-build lang-attribute rewrite
- `apps/wikaniagasukses.com/wrangler.jsonc` — Workers Assets config template
- `apps/wikaniagasukses.com/moon.yml` — task + inputs template

---

## Build sequence

1. Scaffold `apps/steelbandindonesia.com/` with root config files (package.json, tsconfig, next.config, postcss, vitest, .gitignore, moon.yml, wrangler.jsonc, scripts/fix-export-lang.mjs).
2. Register `steelband` project in `.moon/workspace.yml`.
3. `corepack pnpm install` at repo root to populate workspace.
4. Copy `src/lib/*` and `src/test/setup.ts` verbatim; run `moon run steelband:test` with just lib tests present → confirm infra works.
5. Write `src/data/site.ts` + `src/data/catalog.ts` + `src/data/catalog.id.ts` with steel-strapping content lifted from wika.
6. Copy `src/components/*` verbatim; update `site-header.tsx` wordmark + `site-footer.tsx` operator credit.
7. Write `src/app/` route tree for `id` + `en/` mirror. Colocate tests.
8. Source images (web search → download → `public/images/`). Fall back to wika's strapping images where web search comes up empty or licensing is unclear.
9. Add `apps/steelbandindonesia.com/CLAUDE.md` with commands + Cloudflare Workers Builds dashboard setup steps.
10. `moon run steelband:build` locally → inspect `out/` → spot-check `out/en.html` lang attribute.
11. Report back with the dashboard checklist so the user can connect the GitHub repo to the new Worker and trigger the first deploy.

---

## Verification

- `moon run steelband:test` — all copied + new tests pass
- `moon run steelband:build` — completes; `apps/steelbandindonesia.com/out/` contains `index.html`, `en.html`, `products/*/index.html`, etc.
- Spot check: `rg 'lang="id"' apps/steelbandindonesia.com/out/index.html` and `rg 'lang="en"' apps/steelbandindonesia.com/out/en.html`
- Spot check: `rg 'wa.me/628161936543' apps/steelbandindonesia.com/out -l` → WhatsApp links present on home, contact, and every product-family page
- `moon run steelband:dev` — open in browser, walk hero → products → steel-strapping family → click WhatsApp CTA, confirm pre-filled message
- Cloudflare Workers Builds: after the user connects the repo via dashboard, push to `main` and verify the build succeeds and the Worker serves the site. **Not run by me** — requires dashboard action.

---

## Out of scope

- Extracting shared components/lib into a workspace package (future refactor)
- Contact form with server-side submission (static export; WhatsApp-first)
- Custom domain DNS wiring (separate task, fits `infra/dns.yml` pattern)
- SEO sitemap.xml / robots.txt generation (can be a follow-up)
- Analytics integration
