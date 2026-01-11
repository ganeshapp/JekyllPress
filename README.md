# JekyllPress

<p align="center">
  <img src="JekyllPress.png" alt="JekyllPress Logo" width="200"/>
</p>

<p align="center">
  <strong>A polished, mobile-first CMS for GitHub Pages (Jekyll) blogs.</strong>
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

## 📥 Download

**[⬇️ Download Latest APK](https://github.com/ganeshapp/JekyllPress/releases/latest)**

| Build | Architecture | Size |
|-------|--------------|------|
| [jekyllpress-arm64.apk](https://github.com/ganeshapp/JekyllPress/releases/latest) | ARM64 (Modern phones) | ~8.5 MB |
| [jekyllpress-armeabi.apk](https://github.com/ganeshapp/JekyllPress/releases/latest) | ARM32 (Older phones) | ~8.4 MB |
| [jekyllpress-x86_64.apk](https://github.com/ganeshapp/JekyllPress/releases/latest) | x86_64 (Emulators) | ~9.0 MB |

---

## The Problem

GitHub Pages is arguably the best place to host a developer blog:
* **It's Free:** No hosting costs.
* **It's Fast:** Static site generation via Jekyll.
* **It's Version Controlled:** You own your data forever.

**But the writing experience is terrible, especially on mobile.**

To publish a simple post, you usually have to:
1.  Open a desktop IDE (VS Code / Cursor).
2.  Manually create a file with a specific date format: `2026-01-11-my-post.md`.
3.  Manually type out YAML Frontmatter.
4.  **Images are a nightmare:** You have to put the image in an assets folder, rename it, compress it yourself, and then manually type the relative Markdown path.
5.  Commit, Push, Handle Merge Conflicts.

On mobile, it's even worse. The GitHub mobile app is designed for code review, not prose writing. You have to click through 10 layers of folders just to find `_posts`. Let alone pasting images or putting links in your posts.

## The Solution

**JekyllPress** is a Flutter-based Android app that treats your GitHub repository like a Headless CMS. It abstracts away the Git complexity and gives you a WordPress-like experience.

### Key Features
* **Zero Git Commands:** No `git pull` or `git push`. The app uses the GitHub REST API directly.
* **Mobile-First Editor:** Write in Markdown with a live preview toggle.
* **Automated Frontmatter:** The app handles the dates, titles, and file naming conventions for you.
* **Smart Image Handling:** * Pick an image from your gallery.
    * **Auto-Compression:** Resizes to max 1080p and compresses (JPEG 85%) to save bandwidth.
    * **Privacy:** Strips EXIF metadata (GPS location) before upload.
    * **Auto-Upload:** Uploads to your configured assets folder and inserts the correct Markdown link automatically.
* **Offline Support:** Write drafts on the plane; sync when you land.

---

## 🛠️ Technical Architecture & Design Choices

We made specific technical trade-offs to keep the app lightweight and fast.

### 1. REST API vs. Git Protocol
* **Decision:** We use the **GitHub REST API** exclusively. We do *not* clone the repository.
* **Why:** A standard `git clone` downloads the entire history of the repository. On a mobile device, this bloats storage and eats data.
* **Trade-off:** We lose the ability to do complex merges.
* **Mitigation:** The app is designed for *content appending*. It assumes you are the primary writer. If a file conflict occurs (rare), the API rejects the update, protecting your data.

### 2. The "Local-First" Image Resolver
* **Problem:** When you add an image in the editor, it takes time to upload. If you are offline, you can't upload it. How do you preview it?
* **Solution:** 1. The app saves a local copy of the compressed image in the app's internal storage.
    2. It maps the filename (e.g., `img_123.jpg`) to the local path in a local database (Hive).
    3. The Markdown Previewer intercepts image requests. It checks: *"Do I have this image locally?"*
        * **Yes:** Load from disk (Instant, works offline).
        * **No:** Load from GitHub Raw URL.

### 3. Read-Only Titles for Existing Posts
* **Decision:** You cannot edit the Title or Date of an *existing* published post.
* **Why:** In Jekyll, the filename (derived from date+title) dictates the permalink URL. Changing the title would rename the file, breaking all existing links to that post on the internet (SEO disaster).
* **Trade-off:** Slightly less flexibility for the user.
* **Benefit:** Prevents accidental broken links.

---

## 🏗️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev) (Android target)
* **State Management:** [Riverpod](https://riverpod.dev)
* **Networking:** [Dio](https://pub.dev/packages/dio) (HTTP client)
* **Local DB:** [Hive](https://docs.hivedb.dev/) (NoSQL for drafts & config)
* **Secure Storage:** [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (For storing GitHub Tokens)

---

## ⚡ Getting Started

### Prerequisites
* A GitHub account.
* A repository hosting a Jekyll blog (standard structure with `_posts/` folder).
* A **Personal Access Token (PAT)** from GitHub with `repo` scope.

### Installation
1.  Clone this repo.
2.  Run `flutter pub get`.
3.  Run `flutter run`.

### Setup
1.  Launch the app.
2.  Paste your Personal Access Token.
3.  Select your blog repository from the list.
4.  Confirm your image upload directory (default: `assets/images`).
5.  Start writing!

---

## 🤝 Contributing

This is an open-source project. We welcome PRs! 

**Note on Security:** * Never commit your `client_secrets` or API keys.
* The app stores the user's PAT in the device's secure keystore/keychain.

## 👨‍💻 Author

**Gapp** — [www.gapp.in](https://www.gapp.in)

Found a bug or have a feature request? [Open an issue](https://github.com/ganeshapp/JekyllPress/issues)!

## 📄 License

MIT — see [LICENSE](LICENSE) for details.