# JekyllPress Privacy Policy

_Last updated: 2026-10-03 (v2.2.1)_

JekyllPress is an open-source app for Android, macOS and Linux that publishes
posts to a Jekyll blog hosted in **your own GitHub repository**. It is designed
so that your data never touches anything except your device and GitHub.

## The short version

- All app data stays **on your device** and in **your own GitHub repository**.
- There are **no analytics, no trackers, no ads, and no third-party servers**.
- The developer never sees your content, your token, or anything else.

## What the app stores on your device

| Data | Where | Why |
|------|-------|-----|
| GitHub access token (PAT or Device Flow token; also a refresh token and expiry when the sign-in returns them) and the Client ID the Device Flow sign-in used | The system's credential store, as one item: Android Keystore-backed `EncryptedSharedPreferences`; the macOS login keychain (service `com.jekyllpress.jekyllpress`); the Linux Secret Service keyring, e.g. GNOME Keyring (item `com.jekyllpress.jekyllpress/FlutterSecureStorage`) | Authenticating GitHub API calls; re-authorizing without asking again |
| Cached copies of your posts and remote drafts | Local Hive database | Offline reading and faster sync |
| Local drafts and the offline publish queue | Local Hive database | Autosave and publish-when-online |
| Compressed copies of images/videos you attach | App-private storage | Offline preview before upload |
| Repository configuration (owner, repo, branch, folders, site URL) | Local Hive database | Knowing where to read and publish |
| App settings (light/dark/system theme choice) and the map of inserted image names to local files | Local Hive database | Remembering your theme; showing local previews of attached media |

On Android the database and media live in the app's private storage, and
device backups are disabled for the app (`android:allowBackup="false"`), so
none of this data is copied into Android or cloud backups.

On macOS and Linux they live in a folder readable by your user only:
`~/Library/Application Support/com.jekyllpress.jekyllpress` or
`~/.local/share/com.jekyllpress.jekyllpress` (`$XDG_DATA_HOME` if set). A photo
being converted passes through `~/Library/Caches/com.jekyllpress.jekyllpress`
or `~/.cache/com.jekyllpress.jekyllpress` and is deleted afterwards; a video
being compressed (macOS) passes through the system's per-user temporary folder
and the compressed copy is deleted once it is in the app's folder. These
folders are not excluded from Time Machine or other backups: sign out (which
clears the cache) or delete the folder if you do not want cached post content
in your backups.

## What leaves your device

The app talks **only to GitHub**:

- `api.github.com` — reading and writing files in the repository you configured
  (posts, drafts, images, videos), listing your repositories and branches, and
  validating your sign-in (`GET /user`).
- `github.com` — the Device Flow sign-in endpoints (`/login/device/code`,
  `/login/oauth/access_token`) when you use "Sign in with GitHub".
- `raw.githubusercontent.com` — loading images from your repository for the
  markdown preview.
- `avatars.githubusercontent.com` — loading your own GitHub profile picture for
  the dashboard account menu.

Images and videos you attach are uploaded **only to the assets folder of your
own repository**. Photos are re-compressed and **EXIF metadata (including GPS
location) is stripped** before upload. Videos are re-encoded and the
container's metadata boxes, where the recording location is kept, are blanked
before upload.

Nothing is ever sent anywhere else. There is no telemetry, crash reporting, or
usage analytics of any kind.

## What logout deletes

Logging out removes from the device:

- your GitHub access token, refresh token (if any), and auth session data,
- all cached posts and remote drafts,
- all local drafts and queued publishes,
- the local image/video files and the filename map.

Switching to a different repository or branch clears the same local content
(cached posts and drafts, the publish queue, the local media and its filename
map) but keeps you signed in.

The Client ID is kept (it is not a secret) so signing back in stays one tap.
Content already published to your repository is, of course, untouched.

**Logging out is local only — it does not revoke the token on GitHub.** To end
the authorization itself, go to github.com → **Settings** → **Applications** →
**Authorized OAuth Apps** and revoke JekyllPress (or delete the Personal Access
Token under **Settings** → **Developer settings**).

## Uninstalling

Android removes everything with the app. On macOS and Linux, moving the app to
the Trash or `apt remove jekyllpress` leaves the data folder above and the
keychain or keyring item in place. Sign out first (it deletes the token and the
cached content), then delete the folder. The keychain item is listed under
`com.jekyllpress.jekyllpress` in Keychain Access; the keyring item under
`com.jekyllpress.jekyllpress/FlutterSecureStorage` in Passwords and Keys
(Seahorse).

## Your GitHub token

- A **"Sign in with GitHub"** (Device Flow) sign-in uses the Client ID of the
  JekyllPress OAuth App, which is compiled into the app. A Client ID is a
  public identifier, not a secret — no client secret is involved at any point,
  and no token can be issued without you approving a device code on
  github.com. The token GitHub then issues carries the **`repo` scope**: read
  and write access to your repositories, public and private. It is the
  narrowest scope that lets an OAuth app read and commit files in a private
  repository. The app only ever reads and writes the repository you configure,
  but the token is not itself restricted to it. The OAuth App is registered by
  JekyllPress's developer, so GitHub lists your authorization under it — but
  the token is issued to your device and the developer never receives it or
  anything else about your account.
- That token **does not expire**, and no refresh token is issued with it; it
  stays in the credential store until you log out or revoke it on GitHub. (A
  build configured with a GitHub App Client ID instead gets an expiring token
  plus a refresh token, which the app rotates automatically.)
- A **Personal Access Token** is stored as-is in the credential store. Use a
  fine-grained token scoped to your blog repository if you want to grant access
  to that repository only.
- The token is only ever sent to GitHub over HTTPS, and it is never logged.

## Permissions the app requests

- **Internet / network state** — GitHub API access and offline detection.
- **Camera** (Android) — only when you choose "Take photo" for a post image.
- **Photos/media** (Android) — only when you attach an image or video from your
  gallery. On macOS and Linux the app reads only the files you pick in the file
  dialog.

## Changes and contact

This policy may change as the app evolves; the current version always lives at
[github.com/ganeshapp/JekyllPress/blob/main/PRIVACY.md](https://github.com/ganeshapp/JekyllPress/blob/main/PRIVACY.md).
Questions or concerns: [open an issue](https://github.com/ganeshapp/JekyllPress/issues).
