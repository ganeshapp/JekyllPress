# Changelog

## 2.0.1 — 2026-08-18

Fixes external links doing nothing on devices with more than one browser
installed, which blocked the new sign-in flow.

### Fixed
- **Links now open.** `MainActivity` carried `android:taskAffinity=""` (present
  since 1.0.0 but never exercised, because 1.x only copied links to the
  clipboard). With no task affinity, a browser launched from the "Open with"
  chooser started in its own task without being brought to the foreground — the
  button appeared to do nothing. Removed the empty affinity.
- Links now prefer an in-app browser tab (Custom Tabs), which needs no task
  switch and skips the "Open with" chooser entirely, falling back to an external
  browser and then to copying the link. This covers every link in the app,
  including the device-flow verification page.
- "Save & sign in" no longer clips its label at larger system font scales.

## 2.0.0 — 2026-08-17

A ground-up overhaul: JekyllPress now works with any Jekyll site on GitHub, not
just one hardcoded layout.

### Editor
- Reworked body field: internally scrolling (fixes the scroll-vs-text-selection
  fight), no more rebuild storms on cursor moves, undo/redo, spell check.
- Live preview keeps its state across tab switches; keyboard-dismiss affordance.
- Post settings sheet: publication date/time, layout, categories, and tags —
  no hand-written YAML. Unrecognized front matter fields on existing posts are
  preserved byte-exact.
- Photos: gallery or camera, compressed (~1080p JPEG), EXIF/GPS stripped,
  auto-uploaded, markdown inserted. Video support: H.264 re-encode with the
  short edge capped at 640px (25MB upload cap) and an HTML5 `<video>` embed.
  Collision-safe media filenames.
- Publishing is gated on pending/failed media uploads, with retry.

### Publishing
- Unicode-safe filename slugs (punctuated, accented, and non-Latin titles no
  longer crash publish), YAML-escaped titles, full timezone-aware timestamps.
- Minimal front matter (`title` + `date`) by default so `_config.yml` defaults
  apply; optional per-site front matter defaults.
- Stale-SHA (409) refetch-and-retry, duplicate-filename auto-suffixing, and a
  conflict dialog (overwrite / keep both) when a post changed on GitHub
  mid-edit.
- Post delete from GitHub; save-as-draft to `_drafts`; promote draft to post.
- Offline publish queue: queued posts publish automatically when connectivity
  returns, with a dashboard banner, manual retry, and reopen-in-editor for
  failures.

### Auth
- **Sign in with GitHub** via Device Flow — no token pasting, no client
  secret in the APK. Bring your own GitHub App Client ID (one-time paste, or
  bake it in with `--dart-define=GITHUB_CLIENT_ID=...`). Automatic single-flight
  token refresh with crash-safe rotation.
- PAT sign-in kept as a secondary path with a working format check.
- One shared authenticated Dio client: consistent auth, rate-limit-aware error
  messages, debug-only logging with headers redacted, and mid-session 401 →
  clean session-expired logout.
- Offline launches keep you signed in with cached data instead of logging out.
- Logout and repository switches now wipe cached posts, drafts, images, and
  the queue — nothing leaks across accounts.

### Generalization (any Jekyll site)
- Configurable posts folder, drafts folder, assets folder, and extra
  collection folders with a dashboard switcher.
- Branch picker; every read and write respects the selected branch.
- Posts discovered recursively via the git trees API — subfolder layouts work
  and the 1000-file listing cap is gone. Changed-file-only sync with progress.
- Site URL + `baseurl` support: project sites get correct image URLs and
  "View post" links, including custom `permalink:` patterns read from
  `_config.yml`.
- Repo picker includes org/collaborator repos and manual `owner/repo` entry,
  with Jekyll detection.

### Features
- Dashboard search across titles and bodies (posts and drafts).
- Drafts tab with GitHub (`_drafts`) and on-device sections; draft
  resume-or-discard prompt prevents silent overwrites.
- "View post" and "Open site" actions; sync status and last-synced caption.
- Light, dark, and system themes (Material 3 schemes for both brightnesses),
  picked from the dashboard menu and persisted across restarts.
- Every UI string moved into `gen_l10n` ARB resources (English only for now,
  but the app is translation-ready).
- Landscape orientation unlocked.

### Fixes & hygiene
- About screen shows the real installed version (`package_info_plus`) and
  up-to-date copy; links actually open.
- Privacy policy added ([PRIVACY.md](PRIVACY.md)); Android backups disabled
  (`allowBackup=false`) so cached private-repo content stays out of backups.
- Removed the vestigial second draft system and other dead code.
- 370+ unit/widget tests and a CI workflow (analyze + test on every push/PR).

## 1.1.0 — 2026-01-12

- Offline drafts with auto-save, plus draft crash/race fixes (#1).
- Remote repository folder browser for picking the posts folder (#2).
- Auto-capitalization in the editor (#4).

## 1.0.0 — 2026-01-11

- Initial release: PAT sign-in, repository/folder configuration, post list
  with offline cache, markdown editor with preview, image compression and
  upload, one-tap publish to `_posts`.
