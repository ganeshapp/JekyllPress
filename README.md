# JekyllPress

<p align="center">
  <img src="JekyllPress.png" alt="JekyllPress Logo" width="200"/>
</p>

<p align="center">
  <strong>A polished, mobile-first CMS for any Jekyll blog hosted on GitHub.</strong>
</p>

<p align="center">
  <a href="https://github.com/ganeshapp/JekyllPress/releases/latest">
    <img src="https://img.shields.io/github/v/release/ganeshapp/JekyllPress?style=for-the-badge&color=E8A87C" alt="Latest Release"/>
  </a>
  <a href="https://github.com/ganeshapp/JekyllPress/releases/latest">
    <img src="https://img.shields.io/badge/Download-APK-2D4A3E?style=for-the-badge&logo=android" alt="Download APK"/>
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-4DB6AC?style=for-the-badge" alt="MIT License"/>
  </a>
</p>

> Stop using VS Code to write blog posts. Stop fighting with Git on your phone.

## Screenshots

<p align="center">
  <img src="assets/config_screen.jpeg" width="18%" alt="Configure Blog"/>
  <img src="assets/post_list_screen.jpeg" width="18%" alt="Posts List"/>
  <img src="assets/new_post_screen.jpeg" width="18%" alt="New Post"/>
  <img src="assets/edit_post_screen.jpeg" width="18%" alt="Edit Post"/>
  <img src="assets/preview_screen.jpeg" width="18%" alt="Preview"/>
</p>

<p align="center">
  <sub>Configure → Browse Posts → Create → Write Markdown → Live Preview</sub>
  <br/>
  <sub>Screenshots are from v1; v2 keeps the same look with more screens (drafts, post settings, device-flow sign-in).</sub>
</p>

## Disclaimer
I use AI to help me code. But I review all the edits.

## Download

**[Download Latest APK](https://github.com/ganeshapp/JekyllPress/releases/latest)** (Android only)

Nothing to register: install it, tap **Sign in with GitHub**, approve the code
on github.com, and pick your blog repository. Details in
[Signing in](#signing-in).

---

## What it does

JekyllPress treats your GitHub repository like a headless CMS, via the GitHub
REST API — no clone, no git commands, no merge conflicts.

### Writing & publishing
- **Markdown editor** built for phones: internal scrolling, undo/redo, spell
  check, sentence auto-capitalization, live preview tab.
- **Front matter without YAML**: a Post settings sheet for date/time, layout,
  categories, and tags. Custom front matter fields on existing posts are
  preserved byte-exact. New posts default to minimal front matter (`title` +
  `date`) so your site's `_config.yml` defaults apply.
- **Photos**: picked or shot in-app, compressed to ~1080p JPEG, EXIF/GPS
  stripped, uploaded to your assets folder, markdown inserted automatically.
- **Videos**: re-encoded to H.264 with the short edge capped at 640px (25MB
  upload cap) and embedded with an HTML5 `<video>` snippet.
- **YouTube**: paste a watch, youtu.be, Shorts or live link to embed the player.
- **Jekyll drafts**: save to `_drafts` on GitHub, promote to post later.
- **Local drafts & autosave**: every keystroke is safe; resume or discard on
  reopen.
- **Offline queue**: publish while offline and it goes out automatically when
  connectivity returns.
- **Conflict-safe**: stale-SHA retries, duplicate-filename auto-suffixing, and
  a proper conflict dialog when the post changed on GitHub while you edited.
- **Delete, search, view post** (permalink-aware, including custom
  `permalink:` patterns read from your `_config.yml`).

### Works with any Jekyll site
- Configurable **posts folder** (`_posts` anywhere, including `docs/_posts`),
  **drafts folder**, and additional **collection folders** with a one-tap
  switcher on the dashboard.
- **Branch picker** — publish to any branch, not just the default.
- **Project sites**: `baseurl`-aware image URLs and post links.
- Posts in **subfolders** (year/category layouts) are found via the git trees
  API, with no 1000-file cap.
- Private repositories fully supported (including preview images).

---

## Signing in

### Option A — Sign in with GitHub (recommended)

Install the APK, tap **Sign in with GitHub**, approve the 8-character code
(auto-copied) on `github.com/login/device`, and you're in. There is nothing to
register and nothing to paste.

**What you're granting.** JekyllPress ships with its own OAuth App Client ID,
and the sign-in requests the **`repo` scope** — read and write access to the
repositories on your account, public and private. It is the narrowest classic
OAuth scope that can read and commit files in a private repository; GitHub has
nothing finer for OAuth Apps. The app only ever touches the repository you
configure, but the token itself is not limited to it. Want narrower access?
Use a fine-grained Personal Access Token (Option B).

**Revoking.** github.com → **Settings** → **Applications** → **Authorized
OAuth Apps** → JekyllPress. Signing out inside the app deletes the token from
your device but does not revoke it on GitHub — do both if you want the
authorization gone entirely.

**Why shipping a Client ID is safe.** A device-flow Client ID is a public
identifier, not a secret: no client secret is ever exchanged (that is the whole
point of Device Flow), and holding the ID gets nobody a token — GitHub only
issues one after *you* approve a device code while signed in to your own
account, and the token is delivered to the device that asked for it. Tokens
issued this way do not expire, so there is nothing to renew; end a session by
signing out and/or revoking as above.

### Option B — Personal Access Token

Create a token with `repo` scope (or a fine-grained token with Contents
read/write on your blog repo) and paste it into the login screen's
"Use a Personal Access Token instead" section. This is the option to pick if
you want to hand JekyllPress access to exactly one repository.

Either way, the credential is stored in Android's Keystore-backed encrypted
storage and only ever sent to GitHub. See [PRIVACY.md](PRIVACY.md).

### Using your own OAuth App or GitHub App (forks, self-builders)

Override the bundled Client ID at build time — no code change needed:

```bash
flutter build apk --dart-define=GITHUB_CLIENT_ID=Ov23xxxxxxxxxxxxxxxx
```

- **OAuth App** ([github.com/settings/developers](https://github.com/settings/developers)):
  enable Device Flow on it. The app requests the `repo` scope, which is
  compiled in as `GitHubAppConfig.scope` in
  [`lib/core/config/github_app_config.dart`](lib/core/config/github_app_config.dart).
  Leave "Expire user access tokens" **off**: the APK ships no client secret,
  and GitHub only supports secret-less refresh for GitHub Apps, so an expiring
  OAuth-App token could not be renewed.
- **GitHub App** ([github.com/settings/apps/new](https://github.com/settings/apps/new)),
  if you prefer fine-grained permissions: set **Contents: Read and write**,
  tick **Enable Device Flow**, install it on your blog repository, and use its
  Client ID (`Iv23...`). GitHub Apps take their permissions from the
  registration and ignore the requested scope; set `GitHubAppConfig.scope` to
  `''` if you'd rather the request omit it. Expiring tokens are fine here —
  the app refreshes GitHub App tokens automatically, without a secret.

A build with an empty `GITHUB_CLIENT_ID` (`--dart-define=GITHUB_CLIENT_ID=`)
falls back to asking for a Client ID on the login screen and storing it on the
device.

---

## Configuration

After signing in, pick a repository (yours, org, or collaborator — or type
`owner/repo` manually). JekyllPress detects Jekyll sites, then lets you
confirm:

| Setting | Default | Notes |
|---------|---------|-------|
| Branch | repo default | any branch; reads and writes both use it |
| Posts folder | `_posts` | any path, e.g. `docs/_posts` |
| Drafts folder | `_drafts` | for GitHub-side drafts |
| Collections | — | extra content folders (e.g. `_notes`), switchable on the dashboard |
| Assets folder | `assets/images` | where photos/videos upload |
| Site URL + baseurl | inferred | powers "View post" links and project-site image URLs |
| Front matter defaults | none | optional layout/categories/tags pre-filled for new posts |

---

## Tech Stack

* **Framework:** [Flutter](https://flutter.dev) (Android target)
* **State Management:** [Riverpod](https://riverpod.dev) (codegen)
* **Networking:** [Dio](https://pub.dev/packages/dio) — one shared authenticated client
* **Local DB:** [Hive](https://docs.hivedb.dev/) (posts cache, drafts, config, publish queue)
* **Secure Storage:** [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (tokens)

### Design choices

* **REST API, not git**: no history download, tiny footprint. Trade-off: no
  merges — the API's SHA checks protect against clobbering, and the app
  surfaces conflicts with an overwrite/keep-both choice.
* **Local-first previews**: attached media is served from disk until GitHub
  has it, so previews work offline and instantly.
* **No post renames**: the filename dictates the permalink; renaming a
  published post would break every existing link to it, so the title of an
  existing post is locked in-app.

---

## Building from source

```bash
git clone https://github.com/ganeshapp/JekyllPress.git
cd JekyllPress
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run            # debug on a connected device
flutter build apk      # release APK
# optional: use your own OAuth App / GitHub App instead of the bundled one
flutter build apk --dart-define=GITHUB_CLIENT_ID=Ov23xxxxxxxxxxxxxxxx
```

Run the checks the CI runs: `flutter analyze && flutter test`.

## Contributing

PRs welcome! Please keep `flutter analyze` clean and the tests green.

**Note on security:** never commit tokens or client secrets. (Device Flow
needs no secret — the Client ID that ships in the app is public by design.)

## Author

**Gapp** — [www.gapp.in](https://www.gapp.in)

Found a bug or have a feature request? [Open an issue](https://github.com/ganeshapp/JekyllPress/issues)!

## License

MIT — see [LICENSE](LICENSE) for details.
