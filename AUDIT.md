# JekyllPress Audit — 2026-08-17

## v2.0.0 status (post-audit)

The roadmap below **shipped in v2.0.0** — all of P0 (correctness fixes + editor
rework), P1 (shared ApiClient + GitHub App Device Flow), P2 (config v2 /
any-Jekyll-site generalization), P3 (video, `_drafts`, delete, search, view
post, publish gating, conflict UX, offline queue), and the P4 hygiene items
(dialogs, keyboard/tab fixes, real About version, privacy policy, landscape,
`allowBackup=false`, dead-code removal, 370+ tests, CI).

Known deliberate gaps (not bugs — descoped):

- **Post rename/redirect**: titles of published posts stay locked; no
  rename-with-redirect flow.
- **Two-pane tablet editor**: landscape is unlocked and light/dark/system
  themes shipped, but there is no dedicated tablet layout.
- **Video snippet template config**: the HTML5 `<video>` embed is a fixed
  owner-pattern snippet, not user-configurable.
- **Compression settings**: image (1080p/85%) and video (short edge ≤640px,
  25MB upload cap) targets are hardcoded, not configurable.
- **Translations**: strings are extracted into `gen_l10n` ARB resources, but
  English (`app_en.arb`) is the only locale shipped.

The remainder of this document is the original v1.1.0 audit, kept for
reference.

---

Full-codebase audit at commit `3e22bbf` (v1.1.0). Method: six parallel reviewers (auth/security, editor UX, publish pipeline, configurability, state & data, product completeness), each finding adversarially re-verified against the code; the crash claims were verified by executing the actual Dart snippets. Plus research on GitHub's 2026 serverless-auth options.

## TL;DR

The app's architecture (Riverpod + feature folders + sealed states) is sound, but the core flows only work for one exact happy path: ASCII titles, the Minimal Mistakes theme, root-domain site, top-level `_posts`, default branch, online launch. Four things are outright broken (see Critical), the editor's jank has two identifiable code root causes (not fat fingers), and generalization requires making ~8 currently-hardcoded values configurable.

## Answers to the owner's four questions

### 1. Replacing the PAT — use a **GitHub App + Device Flow**

Researched against GitHub docs/changelog as of Aug 2026:

- **OAuth PKCE is a trap**: GitHub shipped PKCE params in July 2025, but the token exchange **still requires `client_secret`** for both OAuth Apps and GitHub Apps ("we don't yet distinguish between public clients and confidential clients"). A secret shipped in an APK is trivially extracted. GitHub missed its Q4-2025 goal for secret-less public clients; do not plan around it.
- **Device Flow needs no secret at all** — only the public `client_id` ships in the app.
- **GitHub App beats OAuth App** for this: fine-grained permission (Contents: read/write on *only the blog repo*, vs the terrifying all-repos `repo` scope), and the device-flow exception lets refresh tokens be redeemed with `client_id` alone — so 8-hour access tokens + 6-month rolling refresh tokens work fully backend-free.
- Flow: register a GitHub App (Contents R/W, "Enable Device Flow" on) → app POSTs `/login/device/code` → shows the 8-char code, copies to clipboard, opens `https://github.com/login/device` → polls `/login/oauth/access_token`. ~60 lines with `http` + `url_launcher`. One-time extra step: user installs the app on their blog repo via `github.com/apps/<slug>/installations/new`.
- **Prerequisite refactor**: token injection is copy-pasted across six classes (AuthService, ContentService, GitHubUploadService, RepoRepository, FolderBrowserNotifier, image_provider), and the shared `dio_client.dart` is dead code that would log the Authorization header if revived. Consolidate to one authenticated Dio with an interceptor first, then swap the token source.

### 2. Editor jank — two real root causes

- **Rebuild storm** (`editor_screen.dart:165`, `editor_provider.dart:96`): `TextEditingController` notifies on *selection-only* changes (every cursor move, every handle drag). `_onBodyChanged` unconditionally pushes into the provider; `EditorState` has no `operator==`, so every cursor move rebuilds the entire screen and restarts the 2s autosave timer — whose saved-status cycle triggers three more full rebuilds. Fix: only propagate when `text` actually changed, give `EditorState` equality, and stop watching the whole editor state from the root `build()`.
- **"Selects everything"** (`editor_screen.dart:713` + `617`): the body field is `maxLines: null` inside a `SingleChildScrollView`, so it expands to full document height with zero internal scroll extent — every scroll is a drag *on the editable text*. Flutter interprets tap-then-drag (within double-tap timeout) and long-press-drag as word-by-word **selection extension**, so scrolling sweeps selections; selection handles can't auto-scroll the outer viewport. Fix: give the TextField its own bounded height + `scrollController` (make it the scrollable, `expands: true`), remove the outer scroll view.
- Compounding: `MediaQuery.of(context).size` in build rebuilds the screen on every keyboard animation frame (use `MediaQuery.sizeOf`); `setState` on every tab notification; no undo/redo, so an accidental select-all + keystroke is committed to Hive by autosave within 2 seconds.

### 3. Auto-capitalization — **already fixed at HEAD, ship it**

Commit `f10b960` (PR #8, closes #4) added `TextCapitalization.sentences` to the body and `.words` to the title. The installed build is stale. Residual nit: programmatic text writes reset the keyboard's shift state on some IMEs.

### 4. Filename generation — the suspicion is confirmed, and worse

- **`_toKebabCase` crashes on most real titles** (`publish_service.dart:148`): it truncates the *cleaned* slug using the *original* title's length. Verified by execution: "Hello, World!", "What's New in Flutter?", "Café Notes", emoji, double spaces, trailing space — all throw `RangeError`. Nothing catches it, so the Publish button just spins forever (state sticks at `Publishing`).
- **ASCII-only slugs**: Dart `\w` without the unicode flag strips all Korean/Japanese/accented chars → empty slug → `2026-08-17-.md`, and every non-Latin post that day collides.
- **Unescaped YAML title** (`frontmatter_parser.dart:104`): a `"` in a title produces invalid front matter and **fails the entire Jekyll site build**.
- **Same-day duplicate titles** → sha-less PUT → cryptic `422: "sha" wasn't supplied`.
- **Date is device-local, date-only**: a KST user publishing to a UTC site before 09:00 creates a "future" post that Jekyll silently hides for hours. No time component → same-day posts have undefined order.
- Good news: editing does *not* orphan files — the title is locked for existing posts and updates reuse the original filename/front matter. (The flip side: you can never fix a title typo in-app.)

## Prioritized roadmap

### P0 — correctness fixes (small diffs, do first)
1. Rewrite `_toKebabCase`: clean → *then* truncate by the cleaned string's length; unicode-aware (`RegExp(..., unicode: true)`) or transliterate; fallback slug (e.g. `post-HHMMSS`) for empty results.
2. Escape YAML (`title: "${title.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"`), and write full `date: YYYY-MM-DD HH:MM:SS +ZZZZ`.
3. Wrap publish in try/catch surfacing errors; special-case 409 (stale sha → refetch & retry UX) and 422 (duplicate filename → auto-suffix `-2`).
4. Fix the draft-overwrite data loss: opening a post from the Published tab while an edit-draft exists silently clobbers the draft (`editor_screen.dart:66` + `drafts_provider.dart:170`). Prompt "Resume draft or discard?".
5. Fix offline launch logging the user out (`auth_provider.dart:55`): distinguish network failure (keep authenticated with cached token) from 401 (log out).
6. Editor: the two root-cause fixes from question 2, plus an `UndoHistoryController`.

### P1 — auth overhaul
7. Consolidate to one authenticated Dio (delete/fix `dio_client.dart`; guard any LogInterceptor with `kDebugMode`).
8. GitHub App + Device Flow as primary auth; keep PAT entry as an "advanced" fallback. Global 401 interceptor → re-auth screen. Read `X-RateLimit-*`/`Retry-After` and stop reporting 403 rate limits as "permission denied".
9. Clear posts/drafts/image caches on logout & repo switch (they currently leak across accounts and repos).

### P2 — generalization (the "any Jekyll blog" goal)
10. Extend `AppConfig`: postsPath (default `_posts`), draftsPath (`_drafts`), source subdir (for `/docs` sites), branch (picker, and pass `?ref=` on *reads* — currently all GETs ignore `config.branch`), site URL + baseurl, front matter template. Kill hardcoded `layout: single` / `categories: [blog]` — verified against the owner's live blog repo (`ganeshapp.github.io/_config.yml`): the site sets `defaults → layout: post` and `permalink: /blog/:title/`, and real posts carry only `title` + `date` in front matter. So the hardcoded values are broken *even for the owner's own site today* (they'd override the site default with a nonexistent layout). Correct default behavior: emit **minimal front matter (title + date only)** and let `_config.yml` defaults apply; the front matter template is opt-in for sites that need more.
11. Front matter editing UI in the editor: layout, categories, tags, excerpt, custom fields, date override, `published: false`.
12. Image URLs: respect baseurl (project-page sites currently 404 every image); pass auth headers for private-repo previews (`getAuthHeaders()` exists but has zero call sites).
13. Repo picker: include org/collaborator repos (drop `type=owner`), manual owner/repo entry, and actually call the existing-but-dead `isJekyllRepo()` validation.
14. Recurse into `_posts` subfolders (year/category layouts) via the git trees API (also lifts the 1000-file cap); parallelize first sync with progress.

### P3 — product features
15. Jekyll `_drafts` support (publish-to-drafts, promote to post).
15a. **Video support with compression** (owner request): pick video → compress → upload to assetsPath → insert HTML5 `<video>` snippet. See "Owner additions" below for details.
16. Post delete/unpublish (no DELETE call exists anywhere today).
17. Search/filter on the dashboard.
18. "View post" action (site URL + permalink → url_launcher; the dependency doesn't even exist yet — About-screen links and the login "Create token" button are dead).
19. Publish gate on image uploads (currently a post can go live with in-flight/failed images; the status overlays never update — `ref.read` instead of `ref.watch`, and the autoDispose ImageManager's state evaporates).
20. Conflict UX for desktop-edited posts; offline queue (or delete the README's "Offline Support" claim and the unused `connectivity_plus` dependency).

### P4 — polish & hygiene
21. Light theme + `ThemeMode.system`; unlock landscape/tablet; accessibility (Semantics, 48dp targets, theme-derived text styles); l10n scaffolding.
22. Confirmation dialogs for Logout / Change Repository; keyboard-dismiss affordance; `.next` action on title; keep tab state (`AutomaticKeepAliveClientMixin`) so Preview doesn't reset scroll/undo.
23. Fix About screen version (use `package_info_plus`); privacy policy.
24. Real tests (the single widget test currently fails — Hive isn't initialized) + CI; delete dead code (`addDraft`/`deleteDraft` second draft system, `fetchAllPosts`, `captureAndProcessImage` camera path, `dio_client.dart`).

---

## Owner additions (2026-08-17): spell check, media compression, video support

### A. Spell check (squiggly underlines)
Confirmed missing: no `spellCheckConfiguration` anywhere in `lib/`. Flutter TextFields have native spell check **disabled by default**; enabling it is one line on the body field (`editor_screen.dart:710`):

```dart
spellCheckConfiguration: const SpellCheckConfiguration(),
```

This uses the platform spell checker (Gboard service on Android, native on iOS) and draws the red squiggles. Optionally set `misspelledTextStyle` so the squiggle reads well against the dark theme + monospace font. Cheap win — fold into the P0 editor rework.

### B. Image/video compression before upload
**Images are already compressed** — `image_service.dart:76-83` runs every picked image through flutter_image_compress (short side bounded to 1080px, JPEG quality 85, EXIF stripped), so a 5MB camera photo lands at roughly 200–400KB. The in-code comment ("Max 1080px width") slightly misstates the semantics but the behavior is fine. If uploads have felt full-size, it was likely a video (no pipeline at all) or a pre-1.x build. Possible refinement: make target size/quality a config option (ties into finding "Image pipeline hardcoded to JPEG").

**Videos have no pipeline at all** — `pickVideo` is never called; only `pickImage` exists. Video compression is mandatory before adding support (see C): a 10s phone clip at 50MB+ would be base64-encoded in memory for the contents-API PUT (slow, OOM risk), GitHub hard-caps repo files at 100MB and recommends <50MB, and the whole GitHub Pages site is capped at 1GB — a blog accumulating raw videos would exhaust that fast. Target something like 720p H.264 at ~1.5–2.5Mbps (a 10s clip ≈ 2–3MB). Package options: `video_compress` (simple, quality presets, hardware-accelerated) or a small platform channel to Media3 Transformer (Android) / AVAssetExportSession (iOS). Avoid `ffmpeg_kit_flutter` — retired/archived in 2025.

### C. Video embedding in posts
The owner's live post (gapp.in/blog/ape-index/, source `ganeshapp.github.io/_posts/2026-02-22-ape-index.md`) embeds video as raw HTML in the markdown, which kramdown (`input: GFM`) passes through — the file lives in the same assets folder as images:

```html
<div style="text-align: center;">
  <video autoplay loop muted playsinline controls style="max-width: 300px; border-radius: 12px;">
    <source src="/assets/images/VID-20260222-WA0001.mp4" type="video/mp4">
  </video>
</div>
```

Implementation sketch:
1. Toolbar "Video" button → `_picker.pickVideo(source: gallery)` → compress (see B) → save to `local_videos/`, upload via the existing `uploadImage`-style path to assetsPath (rename that service concept to "media").
2. Insert the `<video>` HTML snippet at the cursor, using the same snippet shape as the owner's existing posts (make the snippet a config template so other users can adjust attributes/styling; the src must respect baseurl per finding "Image markdown uses root-relative path").
3. Preview: flutter_markdown does **not** render raw HTML, so the embed would show as literal text or nothing. Options: detect `<video src>` blocks and render a thumbnail placeholder with a play badge (cheap, honest), or wire `video_player`/`chewie` for real inline playback (heavier). Placeholder is enough for v1 — parity with how the preview already degrades for Liquid tags.
4. Base64 PUT size guard: warn if the compressed file still exceeds ~25MB.

### D. Ground truth from the owner's blog repo (`ganeshapp.github.io`, local checkout)
Facts that recalibrate several findings, verified 2026-08-17 from `_config.yml` and `_posts/`:

- `defaults` gives all posts `layout: post`; real post front matter is **title + date only**. The app's `layout: single` + `categories: [blog]` would override this with a nonexistent layout — broken for the owner's own site, not just for other themes. Minimal front matter is the correct default (see P2 item 10).
- `permalink: /blog/:title/` — categories don't affect URLs on this site, but the app still shouldn't inject them.
- `timezone: Asia/Seoul` matches the owner's device timezone, which is why the date-only/future-post bug hasn't bitten them personally; it remains real for any site/device timezone mismatch.
- `baseurl: ""` (root site) — why root-relative image paths have worked; project-page users still need baseurl handling.
- The site uses **collections** (`_wiki`, `_projects`, `_essays` with output+permalinks) — collections support (P2 item 14 territory) is an owner use case, not just a generalization nicety.
- Photo albums live in a separate repo served via jsDelivr (`album_repo`) to save Pages storage/bandwidth — reinforces why in-post video must be compressed (site cap 1GB), and suggests an eventual "media repo" option.

## Appendix: full verified finding list

_99 findings (deduplicated from 115 raw) from a 13-agent audit, each adversarially verified against the code on 2026-08-17 at commit 3e22bbf. Sorted by severity._


### Critical

- **Selection/cursor changes trigger full-screen rebuild storm and autosave churn (root cause of complaint (a) jank)** (bug) — `lib/features/editor/presentation/editor_screen.dart:165`
  TextEditingController notifies listeners on ANY value change, including selection-only changes (tapping to move the cursor, dragging selection handles, long-press). _onBodyChanged unconditionally pushes the (unchanged) text into the Riverpod provider and restarts the autosave debounce. updateBody() in editor_provider.dart:96-101 always creates a new EditorState via copyWith (EditorState has no operator==, and the generated Notifier's default updateShouldNotify is !identical), so every cursor move notifies. build() watches editorControllerProvider at line 406, so EVERY selection-change frame rebuilds the entire screen — app bar, tab bar, and the full-document TextField — mid-gesture. Worse, _triggerAutoSave() (line 167) restarts the 2s timer on every cursor move; 2s after the user stops, updateAndSave performs a pointless Hive write whose saving→saved→(2s delayed)→idle status transitions (drafts_provider.dart:192-220), watched at line 441, each trigger yet another full-screen rebuild plus an AnimatedContainer animation. Dragging a selection handle therefore causes a rebuild of a potentially huge widget tree on every frame — this is the janky selection the owner complains about.
  _Fix:_ Guard the listeners: in _onBodyChanged, early-return if `_bodyController.text == ref.read(editorControllerProvider).bodyContent` (selection-only change). In updateBody/updateTitle, early-return when the value is unchanged. Stop watching editorControllerProvider in build() — the TextFields already own the text; use ref.read at publish time or watch only narrow `select()` projections where needed (e.g. preview tab). Move the save-status chip into its own Consumer widget so autosave status changes rebuild only the chip.

- **Fully-expanded maxLines:null TextField inside SingleChildScrollView causes scroll-vs-selection gesture conflict (root cause of complaint (a) 'selects everything')** (bug) — `lib/features/editor/presentation/editor_screen.dart:713`
  The body TextField (lines 710-717) uses maxLines:null / minLines:15, so it grows to the full height of the document and never scrolls internally; the page scrolls via the parent SingleChildScrollView (line 617). For any real post the TextField covers essentially the entire scrollable area, so every scroll attempt is a drag ON the editable text. Flutter's built-in TextField gesture handling interprets (1) tap-then-quick-drag within the double-tap timeout as double-tap-and-drag = extend selection word-by-word, and (2) long-press-then-drag (on Android) as word-by-word selection extension — so a user who taps to place the cursor and immediately drags to scroll sweeps a selection across everything they drag over, and rapid re-taps to nudge the cursor register as double-tap (select word) or triple-tap (select paragraph — a whole Markdown paragraph, i.e. visually 'everything'). This is exactly 'moving the cursor sometimes selects everything'. Additionally, dragging a selection handle past the viewport edge cannot auto-scroll: TextField's selection auto-scroll drives only its internal scrollable, which has zero extent here, so selecting more than one screenful is nearly impossible ('selecting a portion to edit is annoying'). Tap-to-place-cursor also triggers RenderEditable.showOnScreen against the outer viewport, causing scroll jumps after taps, amplified by keyboard inset changes.
  _Fix:_ Restructure the Write tab so the body editor is its own scrollable region: give the TextField a bounded height (e.g. Expanded within the Column, with the title/toolbar in a pinned header) and let it use its internal scrollable (maxLines: null with expands: true inside an Expanded). This restores selection-handle auto-scroll, keeps scroll drags from being interpreted as selection gestures on a full-page field, and fixes caret-visibility jumps.

- **_toKebabCase truncates by original title length, crashing on most real titles** (bug) — `lib/core/services/publish_service.dart:148`
  The slug is truncated with the ORIGINAL title's length, but the cleaned string is shorter whenever any character was removed (punctuation, unicode, emoji, apostrophes, collapsed double spaces, trimmed whitespace). substring then throws RangeError, publish fails, and because publishNewPost/_handleSave have no catch, the error is swallowed by the async zone: no snackbar is shown and PublishNotifier state sticks at Publishing. Verified by executing the exact code: 'Hello, World!', "What's New in Flutter?", '안녕하세요 새 글입니다', 'My Post 🎉', 'Hello  Double  Space', 'Trailing space ', and 'Café Notes' all throw RangeError. Only titles that are strictly [a-z0-9_ -] with single spaces survive.
  _Fix:_ Compute the cleaned string first, then truncate with its own length: final s = cleaned; s.substring(0, s.length > 50 ? 50 : s.length). Also wrap publishNewPost/publishUpdate bodies in try/catch that sets PublishFailed.

- **New posts get hardcoded owner-specific front matter (layout: single, categories: [blog]) with no editing UI** (configurability) — `lib/core/services/publish_service.dart:55`
  Every new post is published with 'layout: single' and 'categories: [blog]' baked in. 'single' is a Minimal Mistakes theme layout; on any other Jekyll theme (minima uses 'post') the post will render broken or not at all, and the forced 'blog' category changes permalinks on sites using :categories in permalink config. There is no UI anywhere to set layout, categories, tags, excerpt, permalink, or any custom front matter field, which is the core of a Jekyll CMS. The editor only exposes title and body (editor_screen.dart _buildWriteTab).
  _Fix:_ Add a front matter editor section (layout, categories, tags, excerpt, plus key/value custom fields) in the editor, with per-repo defaults stored in AppConfig; FrontmatterParser.generateFrontmatter already accepts extraFields.


### High

- **Offline app launch silently logs the user out and strands local drafts** (bug) — `lib/core/providers/auth_provider.dart:55`
  AuthNotifier.build() calls _checkExistingAuth(), which calls AuthService.checkExistingAuth() -> validateToken(), a live GET /user. Any network failure (airplane mode, flaky mobile data, GitHub outage) returns AuthFailure('No internet connection'), which _checkExistingAuth maps to AuthUnauthenticated() — so AuthWrapper renders LoginScreen. The stored token is NOT deleted, but the user sees an empty login form and must re-paste a PAT that GitHub only ever displayed once. Meanwhile the app's offline-first Hive caches (drafts_box, posts_box) are unreachable behind the login wall. For a mobile writing app whose About screen touts capturing ideas on the go, an offline launch making drafts inaccessible is a core failure. Note also that AuthFailure's message is discarded here (const AuthUnauthenticated() with no message), so the login screen gives no hint that the token is fine and only the network is down.
  _Fix:_ Distinguish failure kinds: on connectivity errors with a stored token, enter an 'offline authenticated' state (trust the cached token, allow drafts/editing, retry validation in background); only route to LoginScreen on 401/403 or when no token exists.

- **Reopening a post from the posts list silently overwrites a newer existing draft (data loss)** (bug) — `lib/features/editor/presentation/editor_screen.dart:66`
  When the user edits a post, backs out (edits auto-saved as draft 'draft_edit_<fileName>'), and later reopens the SAME post from the posts list (not the drafts list), didChangeDependencies fills the controllers from widget.post (the ORIGINAL published content), while initializeForExistingPost (drafts_provider.dart:170-183) attaches the EXISTING draft as _currentDraft. The first debounced autosave (2s after any keystroke, or immediately on back/background via forceSave) then calls updateAndSave with the original controller text, overwriting the draft's newer edits in Hive. All previous unsaved edits are silently destroyed with no prompt or conflict resolution.
  _Fix:_ In didChangeDependencies (or before), check drafts for an existing draft of widget.post; if found, either load the draft content into the controllers or prompt 'Resume unsaved draft from <time>?' before initializing.

- **Title is interpolated into YAML unescaped — a quote in the title breaks the whole Jekyll site build** (bug) — `lib/core/utils/frontmatter_parser.dart:104`
  generateFrontmatter writes the title into a double-quoted YAML scalar with no escaping. A title containing a double quote (e.g. My "Best" Post) or a backslash produces invalid YAML front matter. Jekyll/GitHub Pages then fails to build the ENTIRE site (all pages 404/stale) until the user manually fixes the file on GitHub. Colons are safe only because of the quotes; quotes and backslashes are not.
  _Fix:_ Escape backslashes and double quotes (title.replaceAll('\\', '\\\\').replaceAll('"', '\\"')) or emit single-quoted YAML with '' doubling, or use a YAML writer package.

- **Slugification is ASCII-only: non-Latin titles yield an empty slug (2026-08-17-.md), no fallback** (bug) — `lib/core/services/publish_service.dart:142`
  Dart RegExp \w without the unicode flag matches only [A-Za-z0-9_], so RegExp(r'[^\w\s-]') strips every Korean/Japanese/Chinese/Cyrillic/accented character. For a fully non-Latin title the slug becomes empty (today it crashes via the substring bug; once that is fixed the filename would be '2026-08-17-.md'). Every non-Latin post that day collides on the same empty-slug filename and gets an ugly URL. For an app being generalized to any Jekyll site owner, non-English titles are a primary use case (the owner's own titles are likely Korean). There is also no fallback slug for punctuation-only titles.
  _Fix:_ Either keep unicode letters (RegExp(r'[^\p{L}\p{N}\s-]', unicode: true) — Jekyll accepts unicode filenames), or transliterate, and fall back to a timestamp/'untitled-<hhmmss>' slug when the result is empty.

- **Reopening a post from Published tab silently overwrites its saved draft** (bug) — `lib/core/providers/drafts_provider.dart:170`
  When the user edits post A, backs out (draft 'draft_edit_<fileName>' saved with their edits), then later taps post A in the Published tab, EditorScreen seeds the text controllers from the remote post content (editor_screen.dart:66-69), but CurrentDraftNotifier.initializeForExistingPost silently adopts the OLD draft as _currentDraft. The UI never shows the drafted edits, and the first keystroke triggers updateAndSave with the remote-based controller text, overwriting the stored draft. The user's drafted edits are permanently lost with no warning. The same edit also exists in two diverged places (Published tab shows remote content, Drafts tab shows the 'Editing' draft) until this clobber happens.
  _Fix:_ In initializeForExistingPost, if an existing draft is found, either return it so the editor loads the draft content (with a 'resume draft?' prompt), or discard the stale draft explicitly. Never adopt a draft whose content the UI is not displaying.

- **Cached posts state set inside PostsNotifier.build() is silently discarded, breaking offline-first display** (bug) — `lib/core/providers/posts_provider.dart:62`
  build() calls _loadFromCacheAndRefresh() (not awaited) and then returns `const PostsInitial()`. _loadFromCacheAndRefresh synchronously sets `state = PostsLoaded(cachedPosts, isRefreshing: true)` before its first await, but in Riverpod 2.6.1 NotifierProviderElement.create ends with `setState(provider.runNotifierBuild(notifier))` (verified in ~/.pub-cache/.../riverpod-2.6.1/lib/src/notifier/base.dart:212), which overwrites any state assigned during build's synchronous prelude with the returned PostsInitial. Result: the dashboard always shows the full-screen 'Loading posts...' spinner (PostsInitial branch in dashboard_screen.dart:376) instead of cached posts until the network sync completes — and offline, until the 30s Dio timeout elapses. The entire cached-first UX (PostsLoading(cachedPosts)/PostsLoaded(isRefreshing) branches) is dead on startup. The same pattern in AuthNotifier.build() (auth_provider.dart:50-53) clobbers the AuthLoading state with AuthInitial (benign only because both render the splash screen).
  _Fix:_ Return the cached state directly from build() (like DraftsNotifier does): `final cached = _loadFromCache(); Future.microtask(refresh); return cached.isNotEmpty ? PostsLoaded(posts: cached, isRefreshing: true, ...) : const PostsLoading();`

- **ImageManager is autoDispose but only ever ref.read: upload status state evaporates and upload failures become invisible** (bug) — `lib/core/providers/image_provider.dart:64`
  imageManagerProvider is generated as AutoDisposeNotifierProvider (image_provider.g.dart) and is never watched anywhere — editor_screen.dart accesses it only via ref.read (lines 336, 880). With zero listeners, the element is disposed by the scheduler right after each read, destroying the Map<String, ImageUploadStatus> state. Consequences: (1) pickImage()'s state writes after the await land on a disposed element and notify nobody; (2) _buildImage's `imageManager.getStatus(filename)` reads a freshly rebuilt notifier whose state is `{}`, so the 'Uploading...' overlay and the 'Upload failed / Retry' overlay (editor_screen.dart:916, 949) can never render; (3) the fire-and-forget `_uploadImageInBackground(...)` (no await, no catchError at line 99) continues running against a disposed provider — its `ref.read(githubUploadServiceProvider)` after dispose trips Riverpod debug assertions and is undefined behavior. Net effect: a background image upload that fails (offline, 401, name conflict) is completely undetectable by the user, who then publishes a post with a broken image link.
  _Fix:_ Annotate ImageManager with `@Riverpod(keepAlive: true)` (or have the editor `ref.watch(imageManagerProvider)`), and give _uploadImageInBackground an error handler; guard state writes with `ref.mounted`-style checks.

- **Repo switch and logout leave stale Hive data: cross-repo cache/draft leakage** (bug) — `lib/core/providers/config_provider.dart:91`
  clearConfig() only deletes the config key; posts_box, drafts_box, and local_image_map are never cleared on 'Change Repository' or logout (dashboard_screen.dart:354-359 calls only clearConfig/logout). Effects: (1) after switching repos, the previous repo's posts are shown as 'cached' posts of the new repo until a successful sync (and permanently if offline); (2) drafts are not repo-scoped — draft IDs are 'draft_edit_<fileName>' — so an 'Editing' draft created against repo A resumes and publishes against repo B with repo A's sha/filename/frontmatter (guaranteed 409/422 failure or a wrong-content post in repo B's _posts); (3) after logout, the next account on the same device sees the previous user's cached private-repo posts and drafts. PostsNotifier also reads config with ref.read (posts_provider.dart:70-72) instead of watching it, so nothing invalidates posts state on config change.
  _Fix:_ On config change and logout, clear posts_box (and optionally namespace cache keys by 'owner/repo'); tag drafts with the repo they belong to and filter/migrate on switch; wipe all boxes on logout.

- **The only test in the suite fails when run; effectively zero working test coverage and no CI** (bug) — `test/widget_test.dart:14`
  test/widget_test.dart is the sole test (not the default counter test, but a trivial smoke test), and `flutter test` fails: the test pumps JekyllPressApp without initializing Hive, ConfigNotifier.build() calls Hive.box('app_config') and throws, and the finder locates 0 widgets with text 'JekyllPress'. There are no unit tests for FrontmatterParser, PublishService filename generation, or ContentService sync, and no .github/workflows directory exists, so nothing catches regressions before the APK releases advertised in the README.
  _Fix:_ Initialize Hive (Hive.init to a temp dir + register adapters + open boxes) in test setUp or inject boxes via provider overrides; add unit tests for FrontmatterParser/PublishService; add a GitHub Actions workflow running flutter analyze + flutter test.

- **Generated front matter hardcodes layout 'single' and categories [blog] — theme-specific, not configurable** (configurability) — `lib/core/services/publish_service.dart:58`
  Every new post is written with layout: single (a Minimal Mistakes theme layout) and categories: [blog]. On any other theme (minima uses 'post', Chirpy, etc.) Jekyll logs 'layout single requested ... does not exist' and renders the post with no layout — a blank unstyled page on the live site. Users also cannot set categories, tags, or any custom front matter from the UI (generateFrontmatter's extraFields parameter is never used by callers). This directly blocks the stated goal of generalizing beyond gapp.in/blog.
  _Fix:_ Add layout/default-categories to AppConfig (detect from _config.yml or let the user set them), expose tags/categories in the editor, or omit layout entirely so Jekyll's front-matter defaults apply.

- **Image markdown uses root-relative path; breaks project-page sites with a baseurl** (configurability) — `lib/core/providers/image_provider.dart:182`
  generateMarkdownImage always emits '![alt](/assets/images/x.jpg)' - a site-root-relative URL. That only works for user/organization pages served at the domain root (username.github.io or a custom domain like gapp.in). For project-page repos, the site is served under https://username.github.io/<repo>/ with baseurl='/<repo>', so every image inserted by the app 404s on the live site. There is no baseurl or site-URL config, and no option to emit '{{ site.baseurl }}/...' or an absolute URL instead. Relatedly, the preview resolver (line 219) blindly prefixes raw.githubusercontent.com to whatever path is in the markdown, so existing posts that reference images via absolute URLs (https://mysite.com/assets/x.png) or Liquid ('{{ site.baseurl }}/assets/x.png') produce garbage URLs like 'https://raw.githubusercontent.com/o/r/main/https://mysite.com/...' and fail to preview.
  _Fix:_ Add siteUrl and baseurl to AppConfig (auto-detect from the repo's _config.yml url/baseurl keys and repo type user-page vs project-page); let the user choose the inserted reference style (baseurl-relative, Liquid, absolute). In resolveImagePath, pass through paths that already start with http(s) or contain Liquid tags.

- **Posts directory hardcoded to top-level _posts; subfolders and collections are invisible** (configurability) — `lib/core/services/content_service.dart:65`
  fetchPostsList queries only 'contents/_posts' and filters direct children by .md/.markdown; the GitHub contents API is not recursive, so posts organized in _posts/2024/, category subfolders (a very common Jekyll layout), custom collections (_notes, _til), or a non-root Jekyll source dir (docs/) never appear. The dashboard will show 'Your _posts folder is empty' for such repos even though the blog has posts, and there is no config field for the posts path (AppConfig only has repoOwner/repoName/branch/assetsPath).
  _Fix:_ Recurse into type=='dir' entries (or use the git trees API with recursive=1) and make the posts path configurable in AppConfig/ConfigScreen.

- **Posts directory hardcoded to root-level '_posts'; no custom source dir, collections, or nested folders** (configurability) — `lib/core/services/github_upload_service.dart:138`
  The posts path is a literal string in both the write path (uploadPost: '_posts/$filename') and the read path (content_service.dart:65 fetches '/repos/{owner}/{repo}/contents/_posts'). There is no config field for it (AppConfig only has repoOwner, repoName, branch, assetsPath). This excludes: sites whose Jekyll source lives in a subdirectory (e.g. GitHub Pages 'publish from /docs' setups need docs/_posts), sites using collections (_notes, _articles), and sites that organize _posts into subfolders by year/category - the GitHub contents API returns only direct children and fetchPostsList filters to markdown files (content_service.dart:73-76), so posts in _posts/2024/ are simply invisible in the dashboard while new posts get written to the flat _posts/.
  _Fix:_ Add postsPath (default '_posts') to AppConfig, reuse the existing FolderBrowserScreen to pick it, and either recurse into subdirectories when listing or use the git trees API (GET /repos/{o}/{r}/git/trees/{branch}?recursive=1) filtered by prefix.

- **Branch is not user-selectable, and all read operations ignore config.branch** (configurability) — `lib/features/config/presentation/config_screen.dart:75`
  The config screen silently stores the repo's default branch (branch: _selectedRepo!.defaultBranch) with no branch picker. Jekyll setups where the source lives on a non-default branch (classic 'source'/'gh-pages' split, or CI-built sites) cannot be used at all. Worse, config.branch is only honored on writes: the PUT bodies include 'branch': config.branch (github_upload_service.dart:90,143), but every GET omits the ?ref= parameter - fetchPostsList and fetchFileContent (content_service.dart:64-69, 93-98), the pre-upload SHA existence check (github_upload_service.dart:70-75), and the folder browser (folder_browser_provider.dart:138-147) all read the default branch. AppConfig even defaults branch to 'main' (app_config.dart:22). The moment branch differs from the default (a Hive record from an older version, or a future branch picker), the app lists posts from one branch, and the SHA check reads the wrong branch causing 422 conflicts or silent overwrites on update.
  _Fix:_ Add a branch dropdown to the config screen (GET /repos/{o}/{r}/branches), and pass queryParameters: {'ref': config.branch} on every contents GET in ContentService, GitHubUploadService, and FolderBrowserNotifier.

- **No handling for revoked/expired token mid-session; no global 401 interceptor** (missing-feature) — `lib/core/providers/posts_provider.dart:165`
  If the PAT is revoked or expires after login (fine-grained PATs have mandatory expiry dates), nothing transitions auth state back to unauthenticated. ContentService throws Exception('Not authenticated') or rethrows raw DioExceptions; PostsNotifier catches everything and either keeps showing stale cache or shows PostsError(e.toString()) — a raw 'DioException [bad response] ... 401' string in the UI. GitHubUploadService maps 401 to 'Authentication failed' but the user stays on the dashboard with no path to re-authenticate except discovering the Logout menu item. There is no Dio interceptor (or shared error handler) that detects 401 and calls AuthNotifier.logout()/prompts re-login, and each of the 5 request classes handles auth errors differently (some rethrow, some return failure strings, folder browser swallows everything as 'Failed to load folders').
  _Fix:_ Add a shared Dio interceptor that, on 401, clears/flags the session and moves AuthState to AuthUnauthenticated with a 'Your token was revoked or expired — please sign in again' message; surface a re-auth prompt instead of raw exception strings.

- **No undo/redo; autosave permanently commits destructive edits within 2 seconds** (missing-feature) — `lib/features/editor/presentation/editor_screen.dart:147`
  There is no undoController, no undo/redo UI, and no draft revision history anywhere in the app (grep for undoController/UndoHistory returns nothing). The TextField's built-in undo stack lives in EditableText state, which is destroyed every time the user switches to the Preview tab because TabBarView (a PageView) disposes offscreen children — and on-screen-keyboard users have no undo gesture anyway. Combined with the accidental select-everything behavior (complaint a), one mistyped character while a large selection is active replaces the whole document, and _triggerAutoSave persists the wiped content to the Hive draft 2 seconds later (updateAndSave overwrites the single draft record in place; drafts_provider.dart:195-205). _handleBack also force-saves unconditionally (line 202) — the discardDraft() API in drafts_provider.dart:266-278 is never called from any UI, so there is no recovery path at all.
  _Fix:_ Pass a persistent UndoHistoryController to the body TextField and add undo/redo buttons to the toolbar; keep the last N draft revisions (or at least the pre-session snapshot) in Hive so an autosaved wipe is recoverable; wire discardDraft() to a 'Discard changes' action.

- **Publish never verifies that referenced images finished uploading** (missing-feature) — `lib/core/providers/publish_provider.dart:58`
  publishNewPost/publishUpdate push the markdown immediately without consulting ImageManager upload statuses or local_image_map. Images are uploaded opportunistically at pick time (image_provider.dart:98-99); if that background upload failed or is still in flight, the post is published with image paths that 404 on the live site. Combined with the autoDispose status-loss bug, there is no point in the flow where the user learns an image is missing. Conversely, images uploaded for a draft the user later deletes remain orphaned commits in the repo forever.
  _Fix:_ Before uploading the post, parse bodyContent for image references, check each against local_image_map/upload status, and (re-)upload pending/failed images first, failing the publish with a clear message if any cannot be uploaded.

- **No search or filtering of posts on the dashboard** (missing-feature) — `lib/features/dashboard/presentation/dashboard_screen.dart:457`
  The Published tab is a single chronological ListView.builder with no search bar, no filter by category/tag/date, and no jump-to. For a blog with a few hundred posts, finding the post to edit requires scrolling the entire list, which makes the app impractical as a CMS for established blogs.
  _Fix:_ Add a search field (title/filename/excerpt match over the already-cached Hive posts) and simple category/year filters.

- **Unguarded LogInterceptor would print Authorization header (PAT) to device logs** (security) — `lib/core/services/dio_client.dart:22`
  The shared dioClient provider adds a Dio LogInterceptor with requestHeader: true and requestBody: true, unconditionally (no kDebugMode guard, despite the comment 'Add logging interceptor in debug mode'). LogInterceptor's default sink is print(), which lands in Android logcat even in release builds. Any request sent through this Dio with an Authorization header would write the full 'Bearer ghp_...' token to the system log, readable via adb/bug reports. Today this is latent because neither dioClient nor createAuthenticatedDio is referenced anywhere in lib/ (all services build their own Dio) — but the provider is generated and exposed, so the first developer who wires it in (the natural move when centralizing auth) silently starts leaking tokens. createAuthenticatedDio (line 48) also logs responseBody: true unconditionally, leaking private repo content to logs.
  _Fix:_ Wrap the interceptor in `if (kDebugMode)`, set requestHeader: false (or redact the Authorization header via a custom logPrint), and either delete this dead file or actually adopt it as the single authenticated client (see the token-injection finding).

- **No onboarding help for creating a PAT and no validation that the selected repo is a Jekyll site** (ux) — `lib/features/auth/presentation/login_screen.dart:271`
  First-run experience for a new Jekyll blogger is rough: the 'Create one on GitHub' button is a TODO that only shows a snackbar telling the user to navigate GitHub settings themselves (no url_launcher in pubspec, so nothing can be opened). The config screen then lists ALL user repos with no check for _config.yml or _posts, so a user can happily configure a non-Jekyll repo and only discover the mistake later via an empty list — and the FAB will then publish _posts/*.md into that arbitrary repo. There is also no in-app explanation of the required 'repo' scope beyond the About screen text.
  _Fix:_ Add url_launcher to open the PAT creation page pre-filled with scopes; after repo selection, probe for _config.yml/_posts and warn if absent; add a short first-run guide.


### Medium

- **403 always reported as a permissions problem; zero rate-limit awareness despite N+1 sync requests** (bug) — `lib/core/services/auth_service.dart:95`
  GitHub returns 403 both for insufficient permissions AND for primary/secondary rate limiting (with X-RateLimit-Remaining: 0 or Retry-After). AuthService maps every 403 to 'Token lacks required permissions' and GitHubUploadService to 'Permission denied', so a rate-limited user is told their token is broken — the worst possible message, since it invites them to regenerate a perfectly good token. No code anywhere reads X-RateLimit-* headers, handles Retry-After, or backs off. This matters because the app's own traffic pattern is request-heavy: ContentService.fetchAllPosts/syncPosts issue one GET per post file (content_service.dart:110-138; a first sync of an N-post blog is N+1 calls), and RepoRepository.getUserRepos paginates all owned repos at 100/page. A generalized app used against a large blog can plausibly hit secondary rate limits.
  _Fix:_ Distinguish rate-limit 403/429 by checking x-ratelimit-remaining == 0 or retry-after headers and show 'GitHub rate limit reached, try again at <time>'. Reduce request volume by fetching _posts via the Git Trees/Repository contents API in bulk or using conditional requests (ETags), which don't count against the limit when 304.

- **Preview images from private repos always fail: auth headers built but never used** (bug) — `lib/core/providers/image_provider.dart:230`
  ImageResolver.getAuthHeaders() constructs a Bearer token header for private repos but has zero call sites (grep confirms). The preview loads remote images with plain `Image.network(resolvedPath)` (editor_screen.dart:903) against raw.githubusercontent.com, which returns 404 for private repositories without authentication. For the generalization goal (any Jekyll site owner, many of whom use private repos), every already-published image in the preview renders as the broken-image placeholder.
  _Fix:_ Pass headers to Image.network (note raw.githubusercontent.com needs a token-authenticated request; alternatively fetch via the contents API with Dio and render bytes), or at minimum plumb getAuthHeaders() through to the image widget.

- **Image upload status overlays in preview never update (ref.read instead of ref.watch)** (bug) — `lib/features/editor/presentation/editor_screen.dart:880`
  _buildImage reads upload status via `ref.read(imageManagerProvider.notifier).getStatus(filename)` at build time and never watches imageManagerProvider's state. ImageManager's state transitions (pending → isUploading → isUploaded/error, image_provider.dart:110-147) therefore never trigger a rebuild of the preview: the 'Uploading...' overlay only appears if an unrelated rebuild happens mid-upload and then STAYS until yet another unrelated rebuild; upload failures may never surface, and tapping 'Retry' (line 980) gives no visible feedback. The status UI (overlays at lines 916 and 949) is effectively dead.
  _Fix:_ Watch the state: `final statuses = ref.watch(imageManagerProvider); final uploadStatus = statuses[filename];` (requires _buildImage to be called from a Consumer/build context, which it is).

- **_insertTextAtCursor mishandles selections: wrong end on reverse selections, never replaces selected text, double-fires listeners with invalid selection** (bug) — `lib/features/editor/presentation/editor_screen.dart:383`
  Three defects in the only text-insertion helper (used for image markdown): (1) it uses selection.baseOffset instead of selection.start — for a reverse selection (dragged right-to-left) baseOffset is the RIGHT end, so the image markdown is inserted at the end of the selection instead of the start; (2) an active selection is never replaced — the markdown is spliced into the middle of the selected text, splitting it, instead of the standard replace-selection behavior; (3) `_bodyController.text = newText` fires the listener once with selection reset to invalid (-1) and composing cleared, then `.selection = ...` fires it again — two provider updates and two autosave triggers per insertion, and if an IME composition were active (e.g. Korean input) the composing region is destroyed.
  _Fix:_ Use a single atomic write: `final sel = _bodyController.selection; final range = sel.isValid ? TextRange(start: sel.start, end: sel.end) : TextRange.collapsed(currentText.length); _bodyController.value = _bodyController.value.replaced(range, text);` then set the collapsed selection in the same TextEditingValue.

- **Empty-content draft states are never persisted, so deleted content resurrects; back navigation claims 'Draft saved' regardless** (bug) — `lib/core/providers/drafts_provider.dart:203`
  updateAndSave and forceSave both skip the Hive write when the draft has no content (`if (updatedDraft.hasContent)`, hasContent = title or body non-empty, local_draft.dart:125). If a user opens a previously saved draft and deletes everything (intending to start over), the deletion is never persisted — the old content resurrects on next resume. Meanwhile _handleBack (editor_screen.dart:197-226) always shows a 'Draft saved' snackbar even when forceSave skipped the write (empty new post) — the UI lies about what was stored.
  _Fix:_ If the draft was previously persisted (lastSavedAt != null) and content is now empty, either persist the empty state or delete the draft record; only show the 'Draft saved' snackbar when a write actually happened.

- **Duplicate filename (same title, same day) fails with cryptic 422; no existence check or suffixing** (bug) — `lib/core/services/publish_service.dart:70`
  createPost always uploads with existingSha: null and never checks whether _posts/<date>-<slug>.md already exists. Publishing two posts with the same (or same-slugging) title on the same day makes GitHub reject the PUT with 422, surfaced to the user as 'Invalid request: "sha" wasn\'t supplied.' — meaningless to a blogger. There is no -2 suffix logic and no friendly message. (Contrast: uploadImage DOES pre-check and silently overwrites, the opposite hazard.)
  _Fix:_ Before PUT, GET the target path; on collision append a numeric suffix to the slug (or ask the user), and translate the 422 sha message into 'A post with this filename already exists'.

- **Post date uses device-local time with no time/zone in front matter — posts can be invisible as 'future' posts** (bug) — `lib/core/services/publish_service.dart:47`
  Filename and front matter date come from DateTime.now() (device local) as date-only (date: 2026-08-17). Jekyll interprets that as midnight in the SITE's timezone and, with the default future: false, skips future-dated posts. A user in UTC+9 (e.g., Korea) publishing to a site whose timezone is UTC (the GitHub Pages default) at 08:00 KST on the 17th produces a post dated 17th while the site clock still reads the 16th — the post silently does not appear for up to 9 hours. Same-day posts also have no time component, so their relative order on the site is undefined.
  _Fix:_ Write a full timestamp with offset in front matter (date: 2026-08-17 08:00:00 +0900 via now and now.timeZoneOffset), and/or let the user configure the site timezone.

- **Stale SHA conflicts (HTTP 409) have no dedicated handling, no re-fetch, no retry** (bug) — `lib/core/services/github_upload_service.dart:187`
  updatePost sends the cached sha (from the Hive posts box, or a draft's originalSha captured when the draft was created — possibly days earlier). If the post changed on GitHub meanwhile, the PUT returns 409, which _handleDioError funnels into the generic 'GitHub error (409): ...' branch (only 401/403/422 are special-cased). The app never re-fetches the current sha, offers no conflict resolution, and has no automatic retry/backoff for any post upload, so the user's Publish button just keeps failing until they happen to pull-to-refresh the posts list.
  _Fix:_ On 409/422-sha errors, GET the file's current sha, show 'Post changed on GitHub — overwrite or reload?', and retry the PUT with the fresh sha if confirmed.

- **Frontmatter regex is not anchored to the start of the file — content before a '---' line is silently discarded** (bug) — `lib/core/utils/frontmatter_parser.dart:21`
  RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n?', multiLine: true) with firstMatch matches a '---' pair ANYWHERE in the file, not only at position 0. A file whose front matter does not start at byte 0 (UTF-8 BOM, or a file created by another tool with a preamble) or a no-frontmatter file containing two '---' horizontal rules gets misparsed: everything before the first '---' is dropped (bodyContent = content.substring(match.end)) and the text between the rules is treated as front matter. If the user then edits and publishes that post, updatePost rewrites the file from the mangled parse, permanently deleting the leading content from the repository.
  _Fix:_ Require the match to start at index 0 (check match.start == 0, and strip a leading BOM first); otherwise treat the file as having no front matter.

- **Reads never pass ?ref= while writes pass branch, and the publishing branch is not user-selectable** (bug) — `lib/core/services/content_service.dart:64`
  All GETs (fetchPostsList, fetchFileContent, uploadImage's existence/sha pre-check) omit the ref query parameter, so they always read the repository's default branch, while PUTs write to config.branch. Today the config screen forces branch = defaultBranch (config_screen.dart:75), which masks the bug — but that same line means users of the very common main-source/gh-pages-publish or non-default source-branch setups simply cannot target their real publishing branch (configurability gap). And the moment config.branch diverges from the default (default branch renamed after config was saved, or a future branch picker), the app will list posts from one branch and write to another, producing invisible posts and stale-sha 409/422 conflicts.
  _Fix:_ Add queryParameters: {'ref': config.branch} to every contents GET (including the image sha pre-check), and add a branch picker to the config screen instead of hardcoding defaultBranch.

- **Filename slug generation breaks for non-ASCII titles and crashes on punctuation-heavy titles** (bug) — `lib/core/services/publish_service.dart:137`
  _toKebabCase strips all characters outside ASCII \w (Dart RegExp \w without unicode flag is [A-Za-z0-9_]), so a Korean, Japanese, Chinese, or accented-European title - exactly the audience of a generalized app - collapses to an empty slug, producing the filename 'YYYY-MM-DD-.md' for every post (second post then collides with the first via the SHA-less create path). Additionally, the final .substring(0, title.length > 50 ? 50 : title.length) indexes the cleaned string using the ORIGINAL title's length; when cleaning shortens the string (e.g. title 'Hello!!! World!!!' is 17 chars but cleans to 'hello-world', 11 chars), substring(0, 17) throws RangeError and the publish flow crashes.
  _Fix:_ Clamp with the cleaned string's own length (s.length.clamp(0, 50)), keep unicode letters (RegExp(r'[^\p{L}\p{N}\s-]', unicode: true)) or transliterate, and fall back to a timestamp slug when the result is empty. Jekyll accepts unicode filenames.

- **Autosave debounce racing clearAfterPublish can resurrect a deleted draft** (bug) — `lib/core/providers/drafts_provider.dart:255`
  EditorScreen._handleSave never cancels _autoSaveTimer (only _handleBack does). If the user types and hits Publish within the 2s debounce window, the timer can fire while clearAfterPublish is awaiting `deleteDraft` — at that moment `_currentDraft` is still non-null, so updateAndSave passes its guard and `box.put`s the draft AFTER the delete completes. The published post's draft is resurrected as a ghost entry in the Drafts tab; if the user later opens and publishes it, publishNewPost generates a fresh dated filename, creating a duplicate post on the blog.
  _Fix:_ Cancel the autosave timer at the start of _handleSave, and in clearAfterPublish set `_currentDraft = null` BEFORE awaiting the delete (plus track a generation/epoch to invalidate in-flight saves).

- **PostsNotifier.refresh() has no concurrency guard; overlapping runs interleave box.clear()/put()** (bug) — `lib/core/providers/posts_provider.dart:114`
  refresh() is invoked from build, the header refresh button, RefreshIndicator, and post-publish (editor_screen.dart:272), with no in-flight flag. Two concurrent runs each capture currentPosts, fetch, then call _saveToCache which does `await box.clear()` followed by per-post puts. Interleaved across awaits, run B's clear() can wipe entries run A just wrote, leaving a partial/mixed cache on disk, and the final in-memory state is whichever run finishes last (potentially the staler fetch). _saveToCache is also non-atomic on its own: a crash between clear() and the puts loses the entire cache.
  _Fix:_ Add an `_isRefreshing` guard (return or coalesce concurrent calls) and replace clear+loop with a single `box.putAll(...)` plus targeted deletes of removed keys.

- **Draft save failures display as 'Saved': DraftsNotifier.saveDraft swallows exceptions** (bug) — `lib/core/providers/drafts_provider.dart:77`
  saveDraft catches all exceptions internally and only records them in DraftsState.error, returning normally. CurrentDraftNotifier.updateAndSave awaits saveDraft and, seeing no exception, sets DraftSaveStatus.saved and updates _lastSavedAt — so if the Hive write failed (disk full, corrupted box), the editor's status chip shows 'Saved' and _handleBack shows the 'Draft saved' snackbar while nothing was persisted. The DraftSaveStatus.error branch (line 222-227) is unreachable for storage failures, and no UI ever renders DraftsState.error. updateAndSave also sets status to 'saved' when hasContent is false and nothing was written at all (line 203-214).
  _Fix:_ Have saveDraft rethrow (or return a bool) so updateAndSave/forceSave can set DraftSaveStatus.error; surface DraftsState.error somewhere in the UI.

- **Image files and map entries are never cleaned up; local storage grows unboundedly** (bug) — `lib/core/services/image_service.dart:112`
  Every picked image leaves two permanent files: the image_picker temp copy (never deleted after compression in _processImage) and the compressed copy in Documents/local_images. ImageService.deleteLocalImage and clearAllLocalImages exist but grep confirms they are never called anywhere, and localImageMapBox entries are only ever added (image_provider.dart:87), never removed — not on publish, draft delete, or logout. Long-term use accumulates megabytes of orphaned JPEGs and an ever-growing Hive map that resolveImagePath consults on every preview render.
  _Fix:_ Delete the picker temp file after compression; on successful upload + publish (or draft deletion), remove the local file and the map entry; call clearAllLocalImages on logout.

- **Switching repositories shows the previous repo's cached posts; posts cache never invalidated per repo** (bug) — `lib/core/providers/posts_provider.dart:76`
  The posts Hive box is keyed by filename only and is not scoped to or cleared on repo change: 'Change Repository' calls configNotifier.clearConfig() which deletes only the config key, and PostsNotifier._loadFromCacheAndRefresh loads whatever is in posts_box first. After configuring repo B, the dashboard initially renders repo A's posts (PostsLoaded with isRefreshing) until the network sync replaces them; on sync failure it keeps showing repo A's posts under repo B's header. Tapping one opens the editor and Publish would write repo A's post into repo B's _posts.
  _Fix:_ Clear posts_box (and drafts referencing the old repo) on config change, or namespace cache keys by owner/repo and filter in _loadFromCache.

- **Token injection duplicated across six classes; blocks clean swap to GitHub Device Flow OAuth** (code-quality) — `lib/core/services/content_service.dart:60`
  Every service independently reads the raw token from SecureStorageService and hand-builds an Authorization header per request: AuthService, ContentService, GitHubUploadService, RepoRepository, FolderBrowserNotifier (_loadFolders), and image_provider.getAuthHeaders(). Each also constructs its own Dio with copy-pasted BaseOptions. The file designed to centralize this (dio_client.dart) is dead code. Consequence for the owner's generalization goal: moving from PAT to GitHub Device Flow OAuth (the right UX for 'any Jekyll site owner') requires touching all six token consumers. Device Flow needs: a registered OAuth app client_id, POST https://github.com/login/device/code, showing user_code + opening github.com/login/device, polling login/oauth/access_token, then storing the resulting access token — plus 401-triggered re-auth. With a single authenticated Dio + auth interceptor, that swap would be confined to AuthService and storage; today it is a shotgun change.
  _Fix:_ Adopt one Riverpod-provided Dio with an auth interceptor (onRequest reads the token; onError handles 401) and inject it into all services; delete the per-service Dio construction. Then Device Flow becomes an AuthService-only change: add device-code request/poll methods and store the OAuth access token under the same storage key.

- **Dead posts_provider draft API (addDraft/deleteDraft/_saveToCache draft handling) contains latent bugs** (code-quality) — `lib/core/providers/posts_provider.dart:180`
  The app has two parallel draft systems: BlogPost.isLocalDraft in posts_box (addDraft/deleteDraft/localDrafts carry-over in refresh) and LocalDraft in drafts_box (the one actually used). Grep confirms addDraft and PostsNotifier.deleteDraft have zero call sites. The dead code is not harmless if revived: deleteDraft calls `await draft.delete()` (HiveObject.delete throws HiveError when the object is not stored in a box, which is true for any draft built in memory), and `currentPosts.removeWhere((p) => p.fileName == draft.fileName)` matches ALL drafts because local drafts have fileName == null. _saveToCache silently drops every isLocalDraft post (fileName null) from the persisted cache, so the `localDrafts` carried through refresh() (line 153) never survive a restart. updatePost (line 211-218) also mutates the previous state's list in place (`currentPosts[index] = post`) before wrapping it, mutating state without notification.
  _Fix:_ Delete addDraft/deleteDraft, the isLocalDraft carry-over in refresh(), and the fileName-null filtering in _saveToCache; make LocalDraft/drafts_box the single draft system.

- **Repo picker only lists repos the user personally owns (type=owner)** (configurability) — `lib/core/repositories/repo_repository.dart:45`
  getUserRepos passes 'type': 'owner' to GET /user/repos, so organization-owned blogs and repos where the user is a collaborator never appear in the dropdown, and there is no manual owner/repo text entry as a fallback. Team blogs and org-hosted sites (org.github.io) are a common Jekyll Pages pattern; those users cannot configure the app at all.
  _Fix:_ Drop the type filter (default 'all' includes org and collaborator repos), or use affiliation=owner,collaborator,organization_member, and add a searchable field plus manual owner/repo input.

- **Markdown toolbar has no formatting actions at all (no bold/italic/heading/link/list)** (missing-feature) — `lib/features/editor/presentation/editor_screen.dart:758`
  The 'toolbar' contains only an Image button and a Help button that shows a static syntax cheat-sheet. There are no formatting buttons (bold, italic, heading, link, list, quote, code), so users must type all Markdown syntax by hand on a mobile keyboard — and wrapping existing text in ** ** requires the precise selection that complaint (a) shows is nearly impossible. There is no selection-aware formatting (wrap selection, preserve selection after formatting) because no such code exists.
  _Fix:_ Add selection-aware formatting buttons that wrap/prefix the current selection via controller.value.replaced and restore a sensible selection afterwards (e.g. keep the wrapped text selected).

- **Jekyll repo validation (isJekyllRepo) is dead code; picker lists all repos unvalidated** (missing-feature) — `lib/core/repositories/repo_repository.dart:74`
  RepoRepository.isJekyllRepo (checks for _posts, falls back to _config.yml) exists but is never called anywhere in the codebase - the only grep hit is its definition. The config screen dropdown shows every repo the user owns with no Jekyll indicator, filter, or post-selection validation, and saveConfig persists whatever was picked. A user who selects the wrong repo gets an empty dashboard (fetchPostsList treats missing _posts as an empty list, content_service.dart:80-83) and publishing then silently creates a _posts/ directory with committed files in a completely unrelated repository. Even the dead check only looks at the repo root, so it would mis-reject /docs-based Jekyll sites.
  _Fix:_ On repo selection, call isJekyllRepo (extended to also probe docs/_config.yml and configurable source dirs) and show a confirmation warning or a 'Jekyll detected' badge before allowing save; optionally pre-filter/sort the list by detection result.

- **No multi-blog support; switching repos leaks the old blog's cached posts and drafts into the new one** (missing-feature) — `lib/core/providers/config_provider.dart:56`
  Configuration is a single Hive record under the fixed key 'current_config' - a user with two Jekyll sites must destructively reconfigure each time. The 'Change Repository' menu action only calls clearConfig() (dashboard_screen.dart:359); the posts_box, drafts_box, and local_image_map Hive boxes are global and keyed only by filename (posts_provider.dart:21-23, drafts_provider box 'drafts_box', main.dart:24-27), with no repo identifier on BlogPost or LocalDraft. After switching, PostsNotifier._loadFromCache displays the previous blog's posts in the new blog's dashboard until a sync completes, and stale local drafts carrying originalSha/originalFileName from the old repo remain publishable - publishing one writes the old blog's content into the new repository.
  _Fix:_ Namespace the posts/drafts/image caches by 'owner/repo' (composite Hive keys or per-repo boxes), and support a list of saved blog profiles with a switcher instead of a single current_config record. At minimum, clear posts_box on repo change.

- **No _drafts support: drafts are trapped on the device** (missing-feature) — `lib/core/providers/drafts_provider.dart:11`
  Drafts exist only as LocalDraft records in the local Hive box 'drafts_box'; a grep for '_drafts' across lib/ returns zero hits. Jekyll's standard _drafts directory is not readable, writable, or configurable, so a user cannot start a draft on the phone and finish on the desktop (or vice versa), cannot see drafts already in their repo, and loses all drafts if the app is uninstalled. For an app whose pitch is 'capture ideas on the go', repo-backed drafts are the natural workflow for any Jekyll site owner.
  _Fix:_ Add a configurable draftsPath ('_drafts') to AppConfig, list its contents alongside published posts, and offer 'Save to _drafts' (filename without date prefix) plus 'Promote to post' (move to postsPath with date prefix).

- **No connectivity handling anywhere despite connectivity_plus being a declared dependency** (missing-feature) — `lib/main.dart:1`
  pubspec.yaml declares `connectivity_plus: ^6.1.0` under a 'Connectivity' comment, but grep confirms it is never imported in any Dart file. There is no offline detection, no queued-publish, no pre-flight check before publish or image upload; every offline action surfaces only as a Dio connectionError string after the fact (or, per the image finding, not at all). For a mobile writing app this makes autosaved-but-unpublishable sessions confusing.
  _Fix:_ Either wire connectivity_plus into a connectivityProvider consumed by publish/upload flows (disable Publish with an offline banner, auto-retry image uploads on reconnect), or remove the dependency.

- **No offline publish queue despite README's 'Offline Support' claim; connectivity_plus is a dead dependency** (missing-feature) — `pubspec.yaml:38`
  README promises 'Offline Support: Write drafts on the plane; sync when you land', but publishing while offline just fails with 'No internet connection' (github_upload_service._handleDioError connectionError case) and nothing is queued or retried when connectivity returns. connectivity_plus is declared in pubspec.yaml but never imported anywhere in lib/, so the app cannot even tell the user it is offline before they hit Publish.
  _Fix:_ Use connectivity_plus to show an offline banner and disable/queue Publish; add a pending-publish queue (drafts flagged publish-on-reconnect) processed on connectivity restore.

- **No way to delete or unpublish a post** (missing-feature) — `lib/features/dashboard/presentation/dashboard_screen.dart:487`
  PostCard's only interaction is onTap -> edit. There is no long-press menu, swipe action, or editor menu to delete a published post, and no DELETE call to the GitHub contents API exists anywhere in lib/ (the only .delete() calls are Hive/local-file ones). A blogger who publishes by mistake must fall back to desktop Git — the exact workflow the app exists to replace.
  _Fix:_ Add a delete action (long-press on PostCard or overflow menu in the editor) calling DELETE /repos/{owner}/{repo}/contents/{path} with the file SHA, behind a confirmation dialog.

- **Preview cannot render images from private repos and has low fidelity to the real site** (missing-feature) — `lib/features/editor/presentation/editor_screen.dart:903`
  The preview loads non-local images via Image.network(raw.githubusercontent.com/...) with no Authorization header, so for private repos (explicitly supported — the repo picker badges them 'Private') every previously-uploaded image shows the broken-image placeholder. ImageResolver.getAuthHeaders() exists but is never called. More broadly, preview is flutter_markdown with the app's dark theme: no site CSS, no Liquid tags, no code syntax highlighting — acceptable, but the private-image case is a hard failure.
  _Fix:_ Pass token headers to Image.network (raw.githubusercontent.com accepts Authorization for private repos) or fetch via the contents API; optionally offer an 'open rendered post' web preview for fidelity.

- **No management of uploaded assets; camera capture implemented but unreachable; JPEG-only** (missing-feature) — `lib/core/services/image_service.dart:48`
  There is no gallery of previously uploaded images — no way to browse the assets folder, reuse an existing image, or delete a remote image (orphaned images accumulate in the repo forever). ImageService.captureAndProcessImage (camera) is fully implemented but ImageManager only exposes pickImage() from gallery, so the CAMERA permission declared in AndroidManifest is requested for a feature no user can reach. All images are transcoded to JPEG, destroying transparency for PNG diagrams/screenshots common in dev blogs.
  _Fix:_ Add a camera/gallery source chooser in _handleAddImage, an asset browser (contents API on assetsPath) with insert/delete, and preserve PNG for images with alpha.

- **No scheduling or date control: posts are always dated 'today' with no time component** (missing-feature) — `lib/core/services/publish_service.dart:48`
  createPost derives both the filename and front matter date from DateTime.now() with no UI to backdate, future-date (Jekyll's future:true workflow), or schedule a post. The date has no time or timezone ('2026-08-17'), so two posts on the same day have ambiguous ordering, and depending on the site's timezone config a just-published post can be treated as a future post and not render until the next build.
  _Fix:_ Add a date/time picker (default now) writing a full 'YYYY-MM-DD HH:MM:SS +ZZZZ' front matter date while keeping the date-only filename prefix.

- **First sync of a large blog makes one serial API request per post; contents API caps at 1000 files** (missing-feature) — `lib/core/services/content_service.dart:154`
  syncPosts fetches the directory listing then downloads every new/changed file's full content sequentially in a for-loop (await inside loop). A blog with 300 posts means 301 sequential API calls on first launch, with a single spinner and no progress indication; the GitHub contents API also returns at most 1000 entries for a directory, silently truncating very large blogs. SHA-diffing makes later syncs cheap, but the first-run experience for exactly the 'established blogger' target is minutes of blank loading.
  _Fix:_ List files via the git trees API (no 1000 cap), fetch contents with bounded parallelism (Future.wait batches), show 'x of y' progress, and lazy-load bodies only when a post is opened.

- **Editor lacks a markdown formatting toolbar, undo/redo, and word count** (missing-feature) — `lib/features/editor/presentation/editor_screen.dart:768`
  The 'toolbar' contains only Image and Help buttons — no bold/italic/link/heading/list/code insertion helpers, which are table stakes for a mobile markdown editor where typing ** and []() on a soft keyboard is painful. There is no explicit undo/redo control and no word/character count or reading-time indicator for long-form writing.
  _Fix:_ Add a formatting toolbar row (B/I/link/H2/list/quote/code) that wraps or inserts at the current selection, plus a word count in the app bar.

- **Token scopes never verified at login and not communicated in the login UI; docs push over-broad 'repo' scope** (security) — `lib/core/services/auth_service.dart:47`
  validateToken() only calls GET /user, which succeeds for any live token regardless of scopes, then immediately persists the token. A classic PAT without 'repo' scope, or a fine-grained PAT without Contents read/write on the blog repo, 'logs in' successfully and only fails later with confusing errors ('Permission denied', empty repo list). The login screen itself says nothing about required scopes — the only guidance is buried in the About screen and README, both of which tell users to grant the classic 'repo' scope, i.e. full read/write to every repository the user owns. For an app being generalized to arbitrary Jekyll site owners, instructing over-privileged tokens is a real security posture problem, and the app never inspects the X-OAuth-Scopes response header (available on GET /user for classic PATs) to warn early.
  _Fix:_ On login, read X-OAuth-Scopes (classic PATs) and warn if 'repo'/'public_repo' is absent; for fine-grained PATs, probe repo contents access after repo selection and surface a clear scope error. Update login screen + docs to recommend a fine-grained PAT restricted to the single blog repo with Contents: Read & write only.

- **Logout does not wipe cached posts, drafts, image map, or local images** (security) — `lib/features/dashboard/presentation/dashboard_screen.dart:355`
  Dashboard logout clears only the Hive app_config entry and the PAT (SecureStorageService.deleteToken). posts_box (full markdown of every post, including from private repos), drafts_box (unpublished drafts), local_image_map, and the local_images/ directory in app documents all survive logout. The ConfigScreen 'Use different account' button (config_screen.dart:541) is worse: it calls only logout(), not even clearConfig(). On a shared device or when handing the app to another GitHub account, the next user who logs in immediately inherits the previous account's cached posts (PostsNotifier._loadFromCache reads whatever is in posts_box) and drafts. ImageService.clearAllLocalImages() exists but has no caller on the logout path.
  _Fix:_ Make AuthNotifier.logout() (or a session service) also clear posts_box, drafts_box, local_image_map, and call ImageService.clearAllLocalImages(); have 'Use different account' go through the same full cleanup. Optionally warn about unpublished drafts before wiping.

- **'Create one on GitHub' button is a dead TODO — token creation flow is all friction** (ux) — `lib/features/auth/presentation/login_screen.dart:270`
  The single biggest onboarding hurdle for a generalized PAT-based app is minting the token, and the app gives no real help: the 'Create one on GitHub →' button contains a TODO and merely shows a snackbar reciting the GitHub settings path. There is no url_launcher dependency at all (pubspec.yaml has none), and the About screen's _launchUrl (about_screen.dart:437) likewise just copies URLs to the clipboard. GitHub supports pre-filled token creation URLs (e.g. github.com/settings/tokens/new?scopes=repo&description=JekyllPress) that would remove most of this friction; the login screen also lacks any mention of the required scope, expiry advice, or a paste button, and shows the token as an obscured monospace field the user must long-press-paste into.
  _Fix:_ Add url_launcher and open a pre-filled token URL (scopes + description) or, better, implement GitHub Device Flow so users never handle a raw token. At minimum: inline scope instructions and a paste-from-clipboard affordance on the login screen.

- **Image insertion appends at end when field was never focused, and keyboard/focus is not restored after the picker** (ux) — `lib/features/editor/presentation/editor_screen.dart:388`
  If the body field has not been focused (selection is (-1,-1) invalid), _insertTextAtCursor silently appends the image markdown at the END of the document (fallback at lines 390-391) rather than where the user is looking. After the native image picker closes, _handleAddImage never calls _bodyFocusNode.requestFocus(), so the keyboard stays closed and the user must re-tap into the field and re-find their position. The _bodyFocusNode exists (line 31) but is never used for restoration.
  _Fix:_ Capture the selection before launching the picker, restore focus (`_bodyFocusNode.requestFocus()`) and the captured selection after it returns, then insert; if there was never a cursor, insert at 0 or scroll to the appended text.

- **Write/Preview tab switch loses scroll position (and the field's undo stack) because TabBarView disposes offscreen pages** (ux) — `lib/features/editor/presentation/editor_screen.dart:423`
  TabBarView is a PageView that disposes offscreen children; neither tab uses AutomaticKeepAliveClientMixin, a PageStorageKey, or a persistent ScrollController (grep confirms none exist in the project). Checking the Preview and returning to Write therefore dumps the user at the TOP of the document — brutal for long posts, and it also destroys the EditableText state (built-in undo history). Text itself survives only because the controllers live in the State. The preview's scroll position resets the same way.
  _Fix:_ Give each tab's scroll view a persistent ScrollController held in the State (or a PageStorageKey), or wrap tab children in keep-alive wrappers so state survives switching.

- **No way to dismiss the keyboard in the Write tab** (ux) — `lib/features/editor/presentation/editor_screen.dart:716`
  The body field uses textInputAction: TextInputAction.newline (correct for multiline, but it means no Done key), the SingleChildScrollView has no keyboardDismissBehavior, and there is no tap-outside-to-unfocus handler. The only unfocus in the whole screen happens when switching to the Preview tab (line 172-174). On iOS especially, once the keyboard is up the user cannot dismiss it to read their draft full-screen without leaving the Write tab.
  _Fix:_ Add `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` to the Write tab's scroll view and/or a keyboard-toolbar Done button.

- **Publish does not wait for or verify pending/failed image uploads** (ux) — `lib/features/editor/presentation/editor_screen.dart:230`
  pickImage inserts the markdown immediately and fires _uploadImageInBackground without awaiting it. _handleSave never consults ImageManager state, so the user can publish a post while an image is still uploading or after its upload silently failed (the failure overlay is only visible on the Preview tab). Result: a live blog post with broken image links and no warning at publish time. The failed upload state is also purely in-memory (Riverpod state), so after an app restart the retry affordance is gone even though the local file mapping persists.
  _Fix:_ Before publishing, scan state for isUploading/error entries referenced by the body; block or warn ('1 image still uploading / failed — publish anyway?') and re-attempt failed uploads as part of publish.

- **Published post URL is never surfaced and no links can be opened (no url_launcher)** (ux) — `lib/features/about/presentation/about_screen.dart:439`
  PublishSucceeded carries htmlUrl but the success snackbar only shows the filename — there is no 'View post' action, no site URL in AppConfig, and no way to open the live blog from the dashboard. The About screen's _launchUrl admits the gap in a comment and just copies URLs to the clipboard; the login screen's token-help link is likewise inert. Verifying that a publish actually rendered requires leaving the app and typing URLs manually.
  _Fix:_ Add url_launcher; add a 'View' action on the publish success snackbar (htmlUrl or configurable site base URL + permalink) and 'Open blog' in the dashboard menu.

- **Accessibility: no Semantics anywhere, sub-minimum tap targets, hardcoded font sizes** (ux) — `lib/features/dashboard/presentation/dashboard_screen.dart:685`
  The codebase contains zero Semantics widgets/semanticLabel usages (only one Tooltip, on the title lock). The draft delete control is a bare GestureDetector wrapping an 18px icon with 4px padding (~26dp target vs the 48dp minimum) with no label for screen readers — TalkBack users cannot identify or reliably hit it. Nearly all text uses hardcoded pixel sizes (fontSize: 11–17) in raw TextStyles; combined with color-only status chips this makes the app hostile to large-font and vision-impaired users.
  _Fix:_ Replace bare GestureDetectors with IconButton (built-in 48dp target + tooltip), add semantic labels to status chips, and derive text styles from the theme so system font scaling works.

- **Logout and 'Change Repository' execute immediately with no confirmation** (ux) — `lib/features/dashboard/presentation/dashboard_screen.dart:354`
  Selecting 'Logout' from the overflow menu instantly clears the saved config AND the token; 'Change Repository' instantly clears the config (losing the assets path setting). Neither shows a confirmation dialog, and both are adjacent menu items — a mis-tap logs the user out and forces re-entering a PAT, which for many users means regenerating one on desktop. Draft deletion, by contrast, does get a confirm dialog, so the pattern is inconsistent.
  _Fix:_ Add confirmation dialogs to both actions, and pre-fill ConfigScreen with the current repo/assets path when changing repository instead of wiping it.


### Low

- **Client-side token format validator never fires for realistic bad input** (bug) — `lib/features/auth/presentation/login_screen.dart:190`
  The validator uses && between three conditions, so 'This doesn't look like a valid token' is shown only when the input BOTH lacks ghp_/github_pat_ prefixes AND is under 20 chars. Any garbage string of 20+ characters passes straight through to a network round-trip, and a short string starting with ghp_ (e.g. 'ghp_x') also passes. The check as written provides almost no signal; the intent was presumably prefix-OR-length heuristics. Harmless in effect (the server is the real validator) but the code does not do what it appears to do, and it also does not accept-listing other valid prefixes (gho_, fine-grained tokens are covered).
  _Fix:_ Either drop the heuristic entirely (rely on server validation) or fix the logic, e.g. reject when `!(value.startsWith('ghp_') || value.startsWith('github_pat_')) || value.length < 20`, with a gentle non-blocking warning rather than a hard failure.

- **Preview always shows today's date, even for existing posts** (bug) — `lib/features/editor/presentation/editor_screen.dart:842`
  The preview header renders `_formatDate(DateTime.now())` unconditionally, so when editing a post published years ago the preview misrepresents the publication date as today, even though the actual date is preserved on publish (publishUpdate keeps original frontmatter). The preview does not match what the published page will show.
  _Fix:_ Use the original post's date when editing (`editorState.originalPost?.date`), falling back to now for new posts.

- **'Editing' unsaved-changes chip is permanently shown for resumed new-post drafts and never reflects the draft baseline** (bug) — `lib/core/providers/editor_provider.dart:39`
  hasUnsavedChanges treats any non-empty content as unsaved when originalPost == null. A resumed new-post draft is initialized via initializeNewPost() + updateTitle/updateBody (editor_screen.dart:92-97), leaving originalPost null with non-empty content — so the app-bar chip shows 'Editing' forever, even when everything is already persisted in the draft, making the indicator meaningless. updateBody also sets isDirty:true on selection-only listener echoes (see rebuild-storm finding), and the isDirty field is never read anywhere.
  _Fix:_ Track a baseline of the last-persisted draft content and compare against it (or drive the chip purely off DraftSaveStatus), and delete the unused isDirty field.

- **Files over 1 MB decode as empty and can then be truncated on the next publish** (bug) — `lib/core/services/content_service.dart:101`
  For files between 1 and 100 MB the contents API returns content: "" with encoding: "none". fetchFileContent never checks the encoding field, so such a post decodes to an empty string, parses as Untitled/empty, and appears blank in the app. If the user opens it and taps Publish, updatePost PUTs the near-empty reconstruction back with the valid sha — permanently truncating the real file in the repo.
  _Fix:_ If encoding != 'base64' (or content is empty with nonzero size), fetch via the raw media type or the blobs API, or mark the post read-only with an explanatory error.

- **YAML quote-stripping crashes on a single-quote-character value, silently hiding the post** (bug) — `lib/core/utils/frontmatter_parser.dart:59`
  For a field like `title: "` the value is the single character '"', which both startsWith and endsWith '"', so value.substring(1, 0) throws RangeError (verified: RangeError (end): Invalid value: Only valid value is 1: 0). fetchAllPosts/syncPosts catch and `continue`, so the post silently disappears from the app's list with no indication. The parser also does not unescape \" inside double-quoted values and cannot read multiline/block-scalar titles or list-form tags/categories (those survive only via rawFrontmatter passthrough on update).
  _Fix:_ Add a value.length >= 2 guard, unescape quoted scalars, and surface per-file parse failures instead of silently skipping.

- **Image filenames have 1-second resolution — same-second uploads silently overwrite each other** (bug) — `lib/core/services/image_service.dart:68`
  Filenames are img_YYYYMMDD_HHMMSS.jpg. Two images processed within the same second get identical names; uploadImage pre-fetches the existing sha and overwrites the first file on GitHub without any warning, and the local_image_map entry is replaced too, so both markdown references render the same image. Also all images are force-converted to JPEG regardless of source (PNG screenshots lose sharpness/alpha, GIFs become a static frame).
  _Fix:_ Add milliseconds or a short random suffix to the filename, and preserve the source format (or at least PNG) instead of always CompressFormat.jpeg.

- **Second-granularity image filenames collide and silently overwrite remote files** (bug) — `lib/core/services/image_service.dart:62`
  Filenames are img_YYYYMMDD_HHMMSS.jpg. Two images processed within the same second (fast repeated picks, or the same second on different days/devices against one repo) produce identical names: the local_image_map entry is overwritten, and uploadImage's existing-SHA lookup (github_upload_service.dart:67-84) then treats the collision as an update and silently replaces the first image in the repository — retroactively changing the image in any older post that referenced it.
  _Fix:_ Append milliseconds plus a short random suffix (or a content hash) to the filename.

- **updateAndSave's delayed status reset runs against a disposed autoDispose notifier** (bug) — `lib/core/providers/drafts_provider.dart:217`
  After setting DraftSaveStatus.saved, updateAndSave awaits `Future.delayed(2s)` and then reads/writes `state`. currentDraftNotifierProvider is AutoDisposeNotifierProvider watched only by the editor's app bar; if the editor pops within that 2s window (very common: autosave fires on back navigation paths), the provider is disposed and the continuation touches a disposed element — tripping Riverpod debug assertions and relying on undefined post-dispose behavior in release. The `_currentDraft != null` guards elsewhere don't cover this path (guarded only by `state == DraftSaveStatus.saved`).
  _Fix:_ Track a `_disposed` flag via ref.onDispose (or use a Timer cancelled on dispose) and skip the reset when disposed.

- **No Hive corruption recovery or schema migration story** (bug) — `lib/main.dart:24`
  main() opens four boxes with no try/catch: a corrupted box file (e.g., interrupted write during _saveToCache's clear/put cycle) throws during startup and crash-loops the app with no recovery path (no deleteBoxFromDisk fallback). There is also no schema version stored anywhere; BlogPost (typeId 1, 8 fields) and LocalDraft (typeId 2, 9 fields) rely purely on hive_generator field indices, so any future non-nullable field addition will throw runtime cast errors when reading records written by older app versions — relevant since the owner intends to generalize and ship this to other users.
  _Fix:_ Wrap each openBox in try/catch with deleteBoxFromDisk-and-reopen for cache boxes (posts/image map are re-syncable), and store a schema version to gate future migrations for drafts_box (the only box holding unrecoverable user data).

- **BlogPost.dateTime falls back to DateTime.now(), causing nondeterministic sort of malformed posts** (bug) — `lib/core/models/blog_post.dart:74`
  Posts whose frontmatter date fails DateTime.parse (e.g., 'Jan 5, 2024' or a Liquid variable) evaluate dateTime as the current instant, so they always float to the top of the list and shift order on every rebuild/sort. Since generalizing means ingesting arbitrary Jekyll repos with heterogeneous date formats, this will misorder real users' post lists.
  _Fix:_ Fall back to a stable sentinel (e.g., DateTime.fromMillisecondsSinceEpoch(0)) or parse the date from the Jekyll filename prefix (YYYY-MM-DD-slug.md), which is authoritative.

- **FolderBrowserNotifier late fields crash if any navigation runs before initialize, and its errors discard diagnostic detail** (bug) — `lib/core/providers/folder_browser_provider.dart:79`
  `late String _repoOwner; late String _repoName;` are only set in initialize(), which the screen schedules in a post-frame callback — refresh()/navigateToFolder()/navigateUp() invoked before that frame (or after a hot-reload rebuild of the provider without re-running the screen's initState) throw LateInitializationError. The generic error path also collapses every non-404 DioException to the constant 'Failed to load folders', hiding actionable causes (403 rate limit vs 401 bad token), and a 404 on a *repo that doesn't exist* is indistinguishable from an empty directory (state shows an empty folder list).
  _Fix:_ Make repoOwner/repoName nullable with a guard (no-op or error state when unset), or pass them as provider family arguments; include the status code/message in the error string.

- **About screen shows stale hardcoded version 1.0.0 while the app is 1.1.0+2** (bug) — `lib/features/about/presentation/about_screen.dart:8`
  AboutScreen hardcodes _version = '1.0.0' but pubspec.yaml is version: 1.1.0+2, so the visible version is already wrong and will drift every release. The About 'Limitations' text is also drifting from reality as features change (it is the only in-app documentation). No privacy policy exists in the repo or app despite the app handling PATs and uploading user photos — a Play Store listing requirement.
  _Fix:_ Use package_info_plus to read the real version at runtime; add a privacy policy document and link it from About.

- **validateToken persists the token as a hidden side effect on every launch** (code-quality) — `lib/core/services/auth_service.dart:58`
  validateToken() both validates AND writes the token to secure storage, so checkExistingAuth() (validate the already-stored token) redundantly rewrites the same token every app start, and any future caller wanting a dry-run validation (e.g. pre-flight check of a new token before replacing the old one) can't have one. Mixing verification with persistence also means a token is saved before any scope/permission checks could run (see the scope finding).
  _Fix:_ Split into validateToken(token) -> AuthResult (pure) and a separate saveToken call made by the login flow only.

- **MediaQuery.of in build subscribes the whole screen to every keyboard-animation frame** (code-quality) — `lib/features/editor/presentation/editor_screen.dart:707`
  `MediaQuery.of(context).size` registers a dependency on the entire MediaQueryData, including viewInsets. Every frame of the keyboard open/close animation therefore triggers didChangeDependencies → a full rebuild of the whole editor (including the full-document TextField), compounding the jank from the rebuild storm during exactly the moments (focus changes) when the user is interacting with text.
  _Fix:_ Use `MediaQuery.sizeOf(context)` (size-only dependency), or compute the constraint from LayoutBuilder constraints.

- **Redundant double full-screen rebuild on every tab switch** (code-quality) — `lib/features/editor/presentation/editor_screen.dart:175`
  _onTabChanged calls setState(() {}) on every TabController notification; TabController notifies at least twice per switch (indexIsChanging true, then false), so each Write/Preview toggle forces two full-screen rebuilds on top of TabBarView's own animation. Nothing in build() actually depends on _tabController.index, so the setState is pure waste.
  _Fix:_ Delete the setState call (keep the unfocus), or guard it behind `if (_tabController.indexIsChanging) return;` if index-dependent UI is added later.

- **Post-frame provider initialization can clobber early keystrokes; publish reads provider state instead of controllers** (code-quality) — `lib/features/editor/presentation/editor_screen.dart:77`
  The editor provider is initialized in a post-frame callback (lines 77-80) while the controllers get their text and listeners in didChangeDependencies. Any keystroke landing before the callback runs is written to the provider and then overwritten by initializeNewPost()/initializeWithPost(); the controller keeps the text, but the provider (which _handleSave publishes from — lines 231, 254-263 use editorState, not the controllers) is stale until the next keystroke re-syncs the full string. Reading the single source of truth (the controllers) at publish time would eliminate this class of desync entirely.
  _Fix:_ Publish from `_titleController.text` / `_bodyController.text` (like the autosave path already does), and initialize the provider synchronously before attaching listeners.

- **Dead BlogPost-draft code path in PostsNotifier contains latent draft-destroying bugs** (code-quality) — `lib/core/providers/posts_provider.dart:84`
  PostsNotifier.addDraft and PostsNotifier.updatePost are never called from any UI (grep shows no call sites; real drafts live in drafts_box as LocalDraft). The path is booby-trapped if ever wired up: _saveToCache does box.clear() and re-puts only posts with fileName != null, so any isLocalDraft BlogPost (fileName == null) would be erased from Hive on every refresh; and deleteDraft's removeWhere((p) => p.fileName == draft.fileName) matches on null == null, removing ALL drafts from the visible list at once. fetchAllPosts and fetchPostsShaMap in ContentService are likewise unused (only syncPosts is called).
  _Fix:_ Delete the unused addDraft/updatePost/deleteDraft trio and fetchAllPosts/fetchPostsShaMap, or fix them to key drafts by a stable id before reuse.

- **Personal branding and owner-specific claims hardcoded in About screen** (code-quality) — `lib/features/about/presentation/about_screen.dart:10`
  The only 'gapp' occurrences in lib/ are confined to the About screen: _creatorUrl 'https://www.gapp.in', creator name 'Gapp' (line 339), 'www.gapp.in' (line 356), copyright 'Copyright (c) 2026 Gapp' (line 419), and the repo link 'https://github.com/ganeshapp/JekyllPress' (line 9). As author attribution this is acceptable for an open-source app, but the same screen hardcodes product claims that will go stale as the app generalizes ('Only supports repositories with a _posts folder', 'Image uploads are limited to JPEG format', 'Currently Android only', hardcoded _version '1.0.0'), and the help text bakes in the owner's conventions ('usually "assets/images"'). No config value anywhere else in lib/ references gapp.in - runtime behavior is not tied to the owner's site, only to the conventions listed in the other findings.
  _Fix:_ Source version from package_info_plus, move limitation text to a maintained constant or remote doc, and keep creator attribution but ensure limitation claims track actual capabilities as they change.

- **dioClientProvider/createAuthenticatedDio are dead code; every service builds its own Dio, and the dead provider would log auth headers** (code-quality) — `lib/core/services/dio_client.dart:9`
  Grep confirms dioClientProvider and createAuthenticatedDio have no call sites. Instead AuthService, ContentService, GitHubUploadService, RepoRepository, and FolderBrowserNotifier each construct their own Dio with copy-pasted BaseOptions and per-call manual token headers — five places to keep consistent, no shared auth/rate-limit/retry interceptor, and no single point to add ETag caching. Worse, the dead dioClient provider adds `LogInterceptor(requestHeader: true, requestBody: true)` unconditionally (not gated on kDebugMode), so reviving it as-is would print the GitHub PAT Authorization header to logs in release builds.
  _Fix:_ Consolidate on one shared Dio provider with an auth interceptor reading the token from secure storage, gate LogInterceptor on kDebugMode, and inject it into all services.

- **ImageResolver misuses Notifier as a stateless function bag with sync file I/O during build, and its auth-header support is never used** (code-quality) — `lib/core/providers/image_provider.dart:189`
  ImageResolver is an AutoDisposeNotifier with `void build() {}` holding no state — its methods are called via ref.read(...notifier), defeating every Riverpod benefit (no reactivity, element churned per read). resolveImagePath performs synchronous `File(localPath).existsSync()` during markdown image build for every image on every preview frame. Its getAuthHeaders() (needed so Image.network can load images from private repos via raw.githubusercontent.com) has zero call sites — editor_screen.dart:903 calls `Image.network(resolvedPath)` with no headers, so previews of already-published images in private repos always fall into the error builder.
  _Fix:_ Replace ImageResolver with a plain service or family provider; pass Authorization headers to Image.network (raw.githubusercontent.com accepts token auth for private repos) or proxy via the contents API; cache existsSync results.

- **Dark theme only; system light mode is ignored** (configurability) — `lib/main.dart:60`
  MaterialApp sets only theme: AppTheme.darkTheme with no lightTheme/themeMode; app_theme.dart defines only darkTheme and every screen hardcodes dark hex colors (e.g. Color(0xFF162A1E)) rather than using the ColorScheme. Users with system light mode get a permanently dark app with no setting to change it, and adding a light theme later will require touching every hardcoded color.
  _Fix:_ Define a light ColorScheme, set theme/darkTheme/themeMode: ThemeMode.system, and migrate hardcoded colors to Theme.of(context).colorScheme.

- **No way to delete a published post from the app** (missing-feature) — `lib/core/services/github_upload_service.dart:24`
  The pipeline has create (PUT) and update (PUT with sha) but no DELETE /repos/.../contents/{path} call anywhere; only local drafts and local images can be deleted (grep across lib/ confirms the only remote verbs are GET and PUT). A blogger who publishes by accident — likely, given publish errors are silent for many titles — must open github.com to remove the file.
  _Fix:_ Add deletePost using the contents DELETE endpoint (message + sha + branch) with a confirmation dialog, and remove the entry from the Hive cache on success.

- **Title cannot be changed on published posts (locked by design) — rename/redirect flow missing** (missing-feature) — `lib/features/editor/presentation/editor_screen.dart:632`
  To the owner's question: editing does NOT create a new file or orphan the old one — because the title field is disabled for existing posts (enabled: isNewPost, with a lock icon and 'Title is locked for existing posts'), and publishUpdate ignores editorState.title entirely, re-uploading the original frontmatter verbatim to originalPost.fileName. That safely avoids orphaned files, but it means fixing a typo in a published title is impossible in-app. A proper rename needs: PUT new file + DELETE old file (or Git data API), plus updating the frontmatter title independently of the filename (Jekyll allows the title field to differ from the slug — the app could at least allow editing the frontmatter title without renaming).
  _Fix:_ Allow editing the frontmatter title (regenerate/patch the title line while keeping the filename), and optionally offer an explicit rename that creates the new file and deletes the old one atomically-ish.

- **No site URL / permalink config; publish success links to the GitHub file, not the live post** (missing-feature) — `lib/core/services/github_upload_service.dart:111`
  The only URL surfaced after publishing is GitHub's html_url for the committed file (UploadSuccess.htmlUrl from response.data['content']['html_url'], threaded through PublishSucceeded). Because nothing in AppConfig knows the site's public URL, baseurl, or permalink style, the app cannot construct or open the actual published post URL for any user - a core 'view my post' action for a generalized blogging client. The editor's success snackbar (editor_screen.dart:277-281) shows only the filename.
  _Fix:_ Store siteUrl/baseurl/permalink pattern in AppConfig (auto-populated from _config.yml and the repo's pages settings via GET /repos/{o}/{r}/pages), derive the post URL from date+slug+categories, and add a 'View post' action.

- **No localization support; all strings hardcoded in English** (missing-feature) — `lib/main.dart:57`
  pubspec.yaml has no flutter_localizations/intl and MaterialApp declares no localizationsDelegates/supportedLocales; every user-facing string is an inline English literal. Jekyll has large non-English communities (Korean, Japanese, Chinese), so for the 'any Jekyll blogger' goal the app is English-only by construction. Dates are also formatted with hand-rolled helpers (e.g. '${dateTime.day}/${dateTime.month}/${dateTime.year}' in dashboard _formatTimeAgo) ignoring locale.
  _Fix:_ Adopt flutter_localizations + gen-l10n with ARB files, and use intl DateFormat for dates.

- **Android auto-backup not restricted; Hive content backed up and secure-storage restore can brick login** (security) — `android/app/src/main/AndroidManifest.xml:16`
  The manifest does not set android:allowBackup="false" or backup rules, so Android auto-backup includes app data by default. The PAT itself survives safely (EncryptedSharedPreferences' master key lives in Keystore and does not migrate), but the unencrypted Hive boxes — posts_box (full content of possibly-private repos), drafts_box, app_config — are uploaded to the user's Google backup. Additionally, a known flutter_secure_storage failure mode is that restoring the encrypted prefs blob to a new device without its Keystore key causes decryption exceptions on read, which in this app would surface as a failed checkExistingAuth (tolerable) or a crash depending on plugin version.
  _Fix:_ Add android:allowBackup="false" (or dataExtractionRules excluding the Hive directory and FlutterSecureStorage prefs) and set resetOnError-style handling around secure storage reads.

- **Complaint (b) — auto-capitalization — is already fixed at HEAD; no remaining defect in editor fields** (ux) — `lib/features/editor/presentation/editor_screen.dart:717`
  The body TextField has `textCapitalization: TextCapitalization.sentences` (line 717) and the title has `TextCapitalization.words` (line 633), both added in commit f10b960 'fix: enable auto-capitalization in text editor (closes #4)' (Jan 12 2026), which is included in HEAD (v1.1.0); the working tree is clean. autocorrect and enableSuggestions default to true and are not disabled, and keyboardType TextInputType.multiline supports capitalization hints. The complaint is stale for current code — the owner is likely running a pre-fix build. Residual nit: the programmatic `_bodyController.text =` write in _insertTextAtCursor (line 398) resets the IME composing state mid-session, which can momentarily desync the keyboard's sentence-capitalization state after inserting an image.
  _Fix:_ Ship v1.1.0 to the device; when fixing _insertTextAtCursor, use a single controller.value assignment to avoid clearing the composing region.

- **PopScope(canPop: false) disables the iOS interactive back-swipe gesture** (ux) — `lib/features/editor/presentation/editor_screen.dart:409`
  canPop: false blocks the iOS edge-swipe-to-go-back gesture entirely (Flutter disables the interactive pop gesture when canPop is false); users must reach for the top-left back button. Since _handleBack unconditionally saves and pops (there is no confirmation dialog to protect), the pop veto buys nothing that couldn't be done by saving in onPopInvoked with didPop == true, or via a synchronous pre-save.
  _Fix:_ Allow the pop (canPop: true) and perform the draft save in onPopInvokedWithResult / dispose (forceSave is fire-and-forget safe), restoring the swipe-back gesture.

- **Title field lacks textInputAction.next / onSubmitted flow to body** (ux) — `lib/features/editor/presentation/editor_screen.dart:630`
  The title TextField sets no textInputAction and no onSubmitted, so the keyboard shows the default action (Done on iOS) which just closes the keyboard; the user must manually tap into the body field to continue writing. A .next action moving focus to _bodyFocusNode is the expected flow for a two-field editor.
  _Fix:_ Add `textInputAction: TextInputAction.next` and `onSubmitted: (_) => _bodyFocusNode.requestFocus()` to the title field.

- **Assets-path config field leaves OS autocorrect enabled on a repo path input** (ux) — `lib/features/config/presentation/config_screen.dart:412`
  Per the every-text-field input-settings audit: the Image Assets Path TextFormField sets neither autocorrect: false, enableSuggestions: false, nor keyboardType: TextInputType.url — so mobile keyboards will autocorrect/suggest against path segments like 'assets/images' or '_posts', mangling manual path entry for new users configuring their own Jekyll repo (the generalization audience). The login token field correctly disables both (login_screen.dart:159-160), showing the intended pattern.
  _Fix:_ Add `autocorrect: false, enableSuggestions: false, keyboardType: TextInputType.url, textCapitalization: TextCapitalization.none` to the path field.

- **403 responses are always reported as 'Permission denied', hiding rate-limit errors** (ux) — `lib/core/services/github_upload_service.dart:185`
  GitHub returns 403 both for insufficient token scopes and for API rate limiting / secondary rate limits (with an explanatory message and Retry-After header). _handleDioError discards the response body for 403 and shows 'Permission denied', sending users to debug their token when they are actually rate-limited. Meanwhile ContentService has no error translation at all — refresh() surfaces raw DioException text (e.toString()) into PostsError for users to read.
  _Fix:_ Include the GitHub message for 403 and detect x-ratelimit-remaining: 0 / Retry-After to show 'Rate limited — try again in N minutes'; add a similar error mapper for ContentService.

- **Folder browser cannot create folders and only browses the default branch** (ux) — `lib/core/providers/folder_browser_provider.dart:98`
  FolderBrowserNotifier.initialize takes only repoOwner/repoName (no branch; _loadFolders GETs /contents with no ref, so a non-default source branch would show the wrong tree), and the UI only allows selecting existing directories - there is no 'create folder' affordance. A fresh Jekyll repo without an assets/images directory forces the user to type the path manually in the config screen (which works, since the GitHub contents API creates intermediate paths on upload, but the browser flow dead-ends). Also, selecting the repo root is silently rewritten to 'assets/images' (config_screen.dart:391), which may surprise users who intentionally store images at root.
  _Fix:_ Pass config/selected branch into the browser (with ref= on requests), add a 'new folder' path-segment input, and warn rather than silently substitute when root is selected.

- **App is locked to portrait; no landscape or tablet layout** (ux) — `lib/main.dart:40`
  SystemChrome.setPreferredOrientations locks the whole app to portraitUp/portraitDown. On tablets and foldables — where long-form writing with a keyboard is most attractive — landscape typing and side-by-side write/preview are impossible, and all layouts are single-column phone designs.
  _Fix:_ Allow landscape at least on the editor, and use a two-pane write/preview layout above a width breakpoint.

- **Drafts tab lacks pull-to-refresh and the dashboard never shows last-synced time** (ux) — `lib/features/dashboard/presentation/dashboard_screen.dart:561`
  The Drafts tab is a plain ListView.builder with no RefreshIndicator (inconsistent with the Published tab), and PostsLoaded.lastSynced is tracked in state but never rendered anywhere, so in the offline/cached scenario the user cannot tell how stale the 'Published' list is — important given the app deliberately shows cached data on sync failure.
  _Fix:_ Wrap the drafts list in RefreshIndicator and show 'Last synced Xm ago' under the header when displaying cached data.
