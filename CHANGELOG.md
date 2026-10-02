# Changelog

## 2.2.1 — 2026-10-02

### Fixed
- **Videos no longer carry their recording location.** The re-encoder
  copies the source's metadata into the compressed clip, so a video shot on
  a phone was uploaded with its GPS coordinates. The container's metadata
  boxes are now blanked before upload, on every platform. The converter's
  shared temp folder is no longer wiped either; only the app's own output
  file is removed.
- **macOS: the sign-in is one keychain item under an app-specific service
  name** (`com.jekyllpress.jekyllpress`). It was five items under
  flutter_secure_storage's default service name, which every app built with
  the plugin shares, so one app could trigger a keychain password prompt for
  another's token. One item also means at most one "Always Allow" prompt
  after an update, not five. On first launch the items 2.2.0 left under the
  shared name are moved into the app's own item (you stay signed in; macOS
  may ask once per item) and deleted. Android and Linux use the same
  one-item layout; existing sign-ins migrate on first read.
- **Linux: the data folder is now always
  `~/.local/share/com.jekyllpress.jekyllpress`** (`$XDG_DATA_HOME` is
  honoured) and private to your user. It used to be named after the
  executable or the app id depending on whether the GLib development package
  was installed, so the repository setup and local drafts "disappeared" when
  build tools came or went. Data in the old `~/.local/share/jekyllpress`
  folder is moved over on first launch.
- **macOS: HEIC photos (iPhone, Photos.app exports) are converted** with the
  system's `sips` before upload instead of being rejected after you picked
  them. Linux has no HEIC decoder and now says so plainly.
- Desktop: a Refresh button in the folder browser (a mouse cannot
  pull-to-refresh); every screen keeps its content at a readable width in a
  wide window; Tab in the post body indents instead of jumping to the
  toolbar; quitting on macOS waits for the pending autosave.
- Copy that only made sense on a phone (About, the sign-in tagline, hints
  that said "tap") now fits a laptop too, and PRIVACY.md says what
  uninstalling leaves behind on each OS. The Android launcher label matches
  the app name ("JekyllPress").

### Changed
- GitHub API requests identify the app and its version in their User-Agent,
  as GitHub asks.
- The `.deb` recommends `gnome-keyring`, a Secret Service provider, which
  signing in needs.

## 2.2.0 — 2026-10-02

### Added
- **Add YouTube video** toolbar button: paste a link to embed the player.
- **macOS and Linux apps**, built from the same code and attached to each
  GitHub release as a `.dmg` (macOS 10.15+, universal), a `.deb` (Ubuntu
  24.04+) and a `.tar.gz`. Images come from a file dialog and are resized and
  stripped of EXIF in the app (HEIC is not supported); there is no camera, and
  video upload is macOS only. Signing in on Linux needs a Secret Service
  keyring. See the README for the macOS "Open Anyway" step.

### Fixed
- An uploaded video inserted mid-paragraph now gets blank lines around it,
  so kramdown treats the embed as an HTML block.
- The editor toolbar fits on 393dp+ phones and scrolls instead of
  overflowing on narrower ones.

## 2.1.1 — 2026-08-18

### Fixed
- **Tapping an earlier line could select everything back to the caret instead
  of moving it.** Flutter treats a tap as "extend the selection to here"
  whenever it believes Shift is held, and that state can get stuck on a device
  — a paired Bluetooth keyboard, or an IME that emits a Shift press without a
  matching release. In a long post every tap then swallowed the text in
  between. A tap in the editor now always places the caret where you tapped.
  Double-tap-to-select-word and long-press selection are unaffected.

  Note: this could not be reproduced on a stock Android emulator, so it is a
  guard against the known cause of that symptom rather than a confirmed
  root-cause fix. If it persists, the cause is elsewhere on the device.

## 2.1.0 — 2026-08-18

Signing in no longer requires registering anything on GitHub.

### Changed
- **Sign-in is now tap, approve, done.** JekyllPress ships with its own OAuth
  App Client ID, so "Sign in with GitHub" goes straight to the device code —
  no registering a GitHub App, no ticking Enable Device Flow, no installing it
  on your repository, no Client ID to paste. Every step of the old one-time
  setup is gone. A device-flow Client ID is a public identifier, not a secret,
  and a token is still only issued after you approve the code while signed in
  to GitHub.
- **The trade-off: the token carries the `repo` scope** — read and write access
  to your repositories, public and private. It is the narrowest scope an OAuth
  app can request that still reaches files in a private repo. JekyllPress only
  touches the repository you configure, and you can revoke access any time at
  github.com → Settings → Applications → Authorized OAuth Apps. Want access
  limited to one repository? Sign in with a fine-grained Personal Access Token
  instead — that path is unchanged.
- Tokens from this sign-in do not expire, so there is nothing to renew; logging
  out deletes the token from the device (it does not revoke it on GitHub).
- The one-time setup card and the "Change Client ID" escape hatch now appear
  only in builds that ship no Client ID of their own.
- Forks and self-builders can substitute their own OAuth App or GitHub App:
  `flutter build apk --dart-define=GITHUB_CLIENT_ID=...` (see the README).
- About screen and privacy policy now spell out what the sign-in grants and how
  to revoke it.

## 2.0.2 — 2026-08-18

### Changed
- The one-time GitHub App setup no longer drops you into GitHub's full
  registration form. The button now opens it pre-filled (name, homepage,
  Contents: Read & write, webhooks off, private) via GitHub's URL parameters,
  leaving only "Enable Device Flow" to tick — GitHub exposes no parameter for
  that one. The card also spells out the final step, installing the app on your
  blog repository, which is easy to miss and leaves sign-in unable to see it.

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
