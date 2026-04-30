# Finish i18n (Indonesian default, English `/en/*`)

## Context

A prior session introduced i18n to this Next.js static-export site in an isolated Git worktree at `.worktrees/i18n-id-default` (branch `i18n-id-default` based on `origin/main`). Indonesian is the default at the root (`/`, `/products`, etc.) and English lives under `/en/*`. The session was compressed mid-stream, so we need to finish what's left, get the test suite green, and commit.

**The infrastructure is already in place.** The remaining work is narrow: fix 4 failing tests, close a few translation gaps, localize the 404 page, add per-page English metadata, and commit.

---

## Current state (already done)

- **Worktree & repo** — `wika-web` initialized as git, remote `https://github.com/wika-niaga-sukses/website`, worktree checked out at `.worktrees/i18n-id-default` from `origin/main` (commit `0a6a727`). Nothing committed on the feature branch yet.
- **`src/lib/i18n.ts`** — `locales`, `Locale`, `defaultLocale = "id"`, `localizePath`, `stripLocaleFromPath`, `getLocaleSwitchPath`.
- **`src/lib/catalog.ts`** — all getters (`getCategories`, `getCategoryBySlug`, `getProductFamiliesByCategory`, `getProductFamily`, `getFeaturedFamilies`) accept `locale: Locale = defaultLocale` and overlay translations from `@/data/catalog.id`.
- **`src/data/catalog.id.ts`** — translation maps for all 5 categories and all 21 product families (name, summary, intro, imageAlts, applications, features, variants; partial `technicalSummaryValues` / `quoteChecklist`).
- **`src/data/site.ts`** — `getSite(locale)` returns shared + locale-specific tagline/description/industries.
- **Components** — `site-shell`, `site-header`, `site-footer`, `hero`, `category-card`, `whatsapp-cta`, `spec-table`, `locale-switcher`, `locale-document-lang` all take `locale: Locale`.
- **Routes** — every page has `export function XPageContent({ locale })` + a default wrapper for `id`. Mirror tree `src/app/en/*` exists for home, about, contact, industries, products, and both dynamic product routes (category, family). English wrappers re-export `generateStaticParams` and `dynamicParams = false`.

---

## Remaining work

### 1. Fix 4 failing tests

Run: `npm --prefix .worktrees/i18n-id-default test -- --run`

| File | Failure | Fix |
|---|---|---|
| `src/app/contact/page.test.tsx` | `getByText(/jakarta/i)` — multiple matches (heading + address cards). | Use `getAllByText(/jakarta/i)` and assert `.length > 0`. |
| `src/app/products/[categorySlug]/page.test.tsx` | `getByAltText(/cerium oxide product image/i)` — default locale is now `id`, rendered alt is `"Gambar produk Cerium Oxide"`. | Change regex to `/gambar produk cerium oxide/i` (match current default-locale output). |
| `src/app/products/[categorySlug]/[familySlug]/page.test.tsx` — steel strapping | Same alt-text issue. | Change to `/gambar produk steel strapping/i`. |
| `src/app/products/[categorySlug]/[familySlug]/page.test.tsx` — pet strapping | `queryByText(/sku/i)` matches Indonesian "Di**sku**sikan" in WhatsApp CTA title. | Tighten regex to `/\bsku\b/i`. Apply the same tightening to the steel-strapping test's `/sku/i` and `/mh-101/i` guards for consistency (`/mh-101/i` already word-bounded, safe to leave). |

### 2. Close translation gaps

- **`src/data/catalog.id.ts`** — add `technicalSummaryValues` for `steel-strapping` (the other three strapping families have it). Keep the label column (`"Width"`, `"Thickness"`, etc.) in English since labels come from the base. Values like `"550-1020 MPa"` stay as-is (technical). Translate only free-text values (e.g. "Heavy duty loads, pallet banding" → "Beban berat, pengikatan pallet").
- **`performanceGuide`** (exists only on steel-strapping) — **leave English in both locales.** The user's rule: "keep specification and technical words in English." Performance guide is pure technical spec table.
- **`src/components/spec-table.tsx`** — `Variant` and `Specifications` column headers stay English per the same rule (already the case).

### 3. Localize `not-found.tsx`

- **`src/app/not-found.tsx`** — translate to Indonesian, wrap in `<SiteShell locale="id">`, keep `href="/products"`. Copy: "Halaman tidak ditemukan" / "Halaman yang Anda minta bukan bagian dari struktur katalog WIKA." / button "Lihat Produk".
- **Create `src/app/en/not-found.tsx`** — English version wrapped in `<SiteShell locale="en">`, `href="/en/products"`. Next.js App Router serves the nearest `not-found.tsx` per segment.

### 4. Add English metadata to `/en/*` pages

Each `src/app/en/*/page.tsx` currently inherits the Indonesian metadata from `src/app/layout.tsx`. Add `export const metadata: Metadata = { title, description }` sourced from `getSite("en")` to each `/en` route file (home, about, contact, industries, products, category, family). For dynamic routes, use `generateMetadata({ params })` to build title from the localized category/family name.

### 5. SSR `<html lang>` for `/en/*` — out of scope

Root `src/app/layout.tsx` hard-codes `<html lang="id">`. English pages flip to `lang="en"` client-side via `LocaleDocumentLang`. Moving to a `[locale]` dynamic segment would change all route paths and break the current mirrored tree structure. Accept the client-side flip as-is; it doesn't break any assertion.

### 6. Commit

Once tests are green, stage and commit on `i18n-id-default` in two logical commits:

1. **`feat(i18n): infrastructure + Indonesian as default`** — `src/lib/i18n.ts`, updated `src/lib/catalog.ts`, `src/data/catalog.id.ts`, `src/data/site.ts`, `src/components/locale-*.tsx`, `src/components/site-shell.tsx`, and all locale-aware component changes (`hero`, `category-card`, `whatsapp-cta`, `spec-table`, `site-header`, `site-footer`). Updated page files (default `id` wrappers). Include the `not-found` localisation.
2. **`feat(i18n): english route mirrors and metadata`** — `src/app/en/**` files and per-page metadata additions.

Both commits should leave `main` (the repo root) untouched — all work stays on the worktree's branch. **Do not push.** The user will push/open a PR separately.

---

## Critical files

**Edit:**
- `src/app/contact/page.test.tsx` (regex fix)
- `src/app/products/[categorySlug]/page.test.tsx` (alt regex)
- `src/app/products/[categorySlug]/[familySlug]/page.test.tsx` (alt regex + `\bsku\b`)
- `src/data/catalog.id.ts` (steel-strapping `technicalSummaryValues`)
- `src/app/not-found.tsx` (localize + SiteShell)
- Each `src/app/en/*/page.tsx` (add `metadata` / `generateMetadata`)

**Create:**
- `src/app/en/not-found.tsx`

**Already correct — do not touch:**
- `src/lib/i18n.ts`, `src/lib/catalog.ts`, `src/data/catalog.ts` (English base), `src/data/site.ts`, all locale-aware components, all default-`id` page wrappers, all `/en/*` route wrappers.

---

## Verification

Run in the worktree:

```
npm --prefix .worktrees/i18n-id-default test -- --run
npm --prefix .worktrees/i18n-id-default run build
```

Expected: all tests pass (currently 6/10), build completes without errors.

Spot-check in dev (`npm --prefix .worktrees/i18n-id-default run dev`):
1. `/` renders Indonesian hero + nav ("Produk", "Tentang", …), category CTA "Lihat Specifications".
2. `/en` renders English hero + nav ("Products", "About", …), category CTA "View Specifications".
3. `/products/strapping/steel-strapping` — Indonesian copy, technical summary values Indonesian where applicable, performance guide still English, variant names Indonesian.
4. `/en/products/strapping/steel-strapping` — all English.
5. Locale switcher: on `/about` switching to English goes to `/en/about`; on `/en/products/chemical` switching back goes to `/products/chemical`.
6. 404 path `/bogus` shows Indonesian not-found; `/en/bogus` shows English not-found.
7. View-source HTML on `/en` has English `<title>` and `<meta name="description">` (after the metadata step).

Then:

```
git -C .worktrees/i18n-id-default log --oneline
git -C .worktrees/i18n-id-default status
```

Expected: two new commits on `i18n-id-default`, clean working tree.
