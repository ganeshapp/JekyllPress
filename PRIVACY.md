# JekyllPress Privacy Policy

_Last updated: 2026-08-17 (v2.0.0)_

JekyllPress is an open-source Android app that publishes posts to a Jekyll blog
hosted in **your own GitHub repository**. It is designed so that your data never
touches anything except your device and GitHub.

## The short version

- All app data stays **on your device** and in **your own GitHub repository**.
- There are **no analytics, no trackers, no ads, and no third-party servers**.
- The developer never sees your content, your token, or anything else.

## What the app stores on your device

| Data | Where | Why |
|------|-------|-----|
| GitHub access token (PAT or Device Flow token, plus refresh token and expiry) | Android Keystore-backed encrypted storage (`EncryptedSharedPreferences` via `flutter_secure_storage`) | Authenticating GitHub API calls |
| GitHub App Client ID (Device Flow sign-in only) | Same encrypted storage | One-tap re-login |
| Cached copies of your posts and remote drafts | Local Hive database | Offline reading and faster sync |
| Local drafts and the offline publish queue | Local Hive database | Autosave and publish-when-online |
| Compressed copies of images/videos you attach | App-private storage | Offline preview before upload |
| Repository configuration (owner, repo, branch, folders, site URL) | Local Hive database | Knowing where to read and publish |
| App settings (light/dark/system theme choice) and the map of inserted image names to local files | Local Hive database | Remembering your theme; showing local previews of attached media |

Device backups are disabled for the app (`android:allowBackup="false"`), so
none of this data is copied into Android or cloud backups.

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
location) is stripped** before upload.

Nothing is ever sent anywhere else. There is no telemetry, crash reporting, or
usage analytics of any kind.

## What logout deletes

Logging out (or switching to a different repository) removes from the device:

- your GitHub access token, refresh token, and auth session data,
- all cached posts and remote drafts,
- all local drafts and queued publishes,
- the local image/video files and the filename map.

The GitHub App Client ID is kept (it is not a secret) so signing back in stays
one tap. Content already published to your repository is, of course, untouched.

## Your GitHub token

- A **Device Flow** sign-in uses a GitHub App you register on your own account;
  only its public Client ID is stored. Access tokens are short-lived and
  refreshed automatically.
- A **Personal Access Token** is stored as-is in encrypted storage. Use a
  fine-grained token scoped to your blog repository if you can.
- The token is only ever sent to GitHub over HTTPS, and it is never logged.

## Permissions the app requests

- **Internet / network state** — GitHub API access and offline detection.
- **Camera** — only when you choose "Take photo" for a post image.
- **Photos/media** — only when you attach an image or video from your gallery.

## Changes and contact

This policy may change as the app evolves; the current version always lives at
[github.com/ganeshapp/JekyllPress/blob/main/PRIVACY.md](https://github.com/ganeshapp/JekyllPress/blob/main/PRIVACY.md).
Questions or concerns: [open an issue](https://github.com/ganeshapp/JekyllPress/issues).
