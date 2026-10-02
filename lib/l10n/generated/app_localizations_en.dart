// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'JekyllPress';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonBack => 'Back';

  @override
  String get commonUntitled => 'Untitled';

  @override
  String get commonView => 'View';

  @override
  String get loginTagline => 'Your mobile CMS for Jekyll blogs.\nConnect with your GitHub account.';

  @override
  String couldNotOpenBrowserLinkCopied(String url) {
    return 'Could not open browser - link copied: $url';
  }

  @override
  String get pasteClientIdPrompt => 'Paste the Client ID from your GitHub App';

  @override
  String get signInWithGitHub => 'Sign in with GitHub';

  @override
  String get oneTimeSetupTitle => 'One-time setup';

  @override
  String get oneTimeSetupBody => 'This build ships without a Client ID, so signing in without a token needs a free GitHub App on your account. The button below opens GitHub with everything pre-filled - you only have to tick \"Enable Device Flow\", then press Create GitHub App. Copy the Client ID it shows you into the box below.';

  @override
  String get openGitHubAppSetup => 'Open GitHub App setup';

  @override
  String get clientIdLabel => 'Client ID';

  @override
  String get saveAndSignIn => 'Save & sign in';

  @override
  String get usePatInstead => 'Use a Personal Access Token instead';

  @override
  String get patLabel => 'Personal Access Token';

  @override
  String get showTokenTooltip => 'Show token';

  @override
  String get hideTokenTooltip => 'Hide token';

  @override
  String get enterTokenValidation => 'Please enter your GitHub token';

  @override
  String get tokenFormatWarning => 'This doesn\'t look like a GitHub token - double-check it. You can still try connecting.';

  @override
  String get connectWithToken => 'Connect with token';

  @override
  String get createTokenOnGitHub => 'Create a token on GitHub';

  @override
  String get deviceSignInFailed => 'GitHub sign-in failed - try again';

  @override
  String get cancelSignInTooltip => 'Cancel sign-in';

  @override
  String get requestingCodeFromGitHub => 'Requesting a code from GitHub...';

  @override
  String get enterCodeOnGitHub => 'Enter this code on GitHub:';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get openGitHubDeviceLogin => 'Open github.com/login/device';

  @override
  String get waitingForAuthorization => 'Waiting for you to authorize...';

  @override
  String get configTitle => 'Configure Your Blog';

  @override
  String get configTagline => 'Connect your Jekyll repository and tune how posts are published.';

  @override
  String loggedInAs(String username) {
    return 'Logged in as @$username';
  }

  @override
  String get sectionRepository => 'REPOSITORY';

  @override
  String get sectionBranch => 'BRANCH';

  @override
  String get sectionContent => 'CONTENT';

  @override
  String get sectionSite => 'SITE';

  @override
  String get sectionFrontMatterDefaults => 'FRONT MATTER DEFAULTS';

  @override
  String get enterRepoAsOwnerName => 'Enter the repository as owner/name';

  @override
  String get selectRepositoryFirstSnack => 'Please select a repository first';

  @override
  String get rootCannotBeContentFolder => 'The repository root cannot be a content folder';

  @override
  String get changeRepositoryDialogTitle => 'Change Repository?';

  @override
  String get changeRepositoryDialogBody => 'Drafts and cached posts are specific to the current repository and branch, and will be removed. This cannot be undone.';

  @override
  String get changeAction => 'Change';

  @override
  String get pleaseSelectRepository => 'Please select a repository';

  @override
  String failedToSaveConfig(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get chooseRepoHelper => 'Choose the repository that contains your Jekyll blog.';

  @override
  String get loadingRepositories => 'Loading repositories...';

  @override
  String failedToLoadRepos(String error) {
    return 'Failed to load repos: $error';
  }

  @override
  String get selectBlogRepositoryHint => 'Select your blog repository';

  @override
  String get privateBadge => 'Private';

  @override
  String get hideManualEntry => 'Hide manual entry';

  @override
  String get manualEntryPrompt => 'Can\'t see your repo? Enter owner/name manually';

  @override
  String usingRepo(String repo) {
    return 'Using $repo';
  }

  @override
  String get checkingForJekyllSite => 'Checking for a Jekyll site...';

  @override
  String get jekyllSiteDetected => 'Jekyll site detected';

  @override
  String get jekyllCouldNotVerify => 'Could not verify this is a Jekyll site - you can continue anyway';

  @override
  String notJekyllRepo(String postsPath) {
    return 'This does not look like a Jekyll repo (no _config.yml or $postsPath)';
  }

  @override
  String get noReposFoundDeviceAuth => 'No repositories found for this account. If you signed in with your own GitHub App, it only sees repositories it is installed on - install it on your blog repo, then refresh. Otherwise, enter owner/repo manually below.';

  @override
  String get noReposFoundForAccount => 'No repositories found for this account.';

  @override
  String get openGitHubAppInstallations => 'Open GitHub App installations';

  @override
  String get selectARepositoryFirst => 'Select a repository first';

  @override
  String get loadingBranches => 'Loading branches...';

  @override
  String failedToLoadBranches(String branch) {
    return 'Failed to load branches - using \"$branch\"';
  }

  @override
  String get branchHelper => 'Branch posts are read from and published to.';

  @override
  String get defaultBranchBadge => 'default';

  @override
  String get postsFolderLabel => 'Posts Folder';

  @override
  String get postsFolderHelper => 'Folder your published Jekyll posts live in.';

  @override
  String get draftsFolderLabel => 'Drafts Folder';

  @override
  String get draftsFolderHelper => 'Folder Jekyll drafts are saved to.';

  @override
  String get additionalContentFoldersLabel => 'Additional Content Folders';

  @override
  String get addFolder => 'Add folder';

  @override
  String get additionalContentFoldersHelper => 'Jekyll collections you also publish to (e.g. _wiki, _projects). Switch between them from the dashboard.';

  @override
  String get imageAssetsPathLabel => 'Image Assets Path';

  @override
  String get imageAssetsPathHelper => 'Folder where images will be uploaded. Tap the folder icon to browse.';

  @override
  String pathFieldRequired(String field) {
    return 'Please enter the $field';
  }

  @override
  String get invalidPath => 'Invalid path';

  @override
  String get siteUrlLabel => 'Site URL';

  @override
  String get siteUrlHelper => 'Public URL of your published site. Pre-filled from the GitHub Pages convention - change it if you use a custom domain.';

  @override
  String get baseUrlLabel => 'Base URL';

  @override
  String get baseUrlHelper => 'Project pages are served under /<repo> (e.g. https://user.github.io/blog needs baseurl /blog) - image links are prefixed with it. Leave empty for user/org sites and custom domains served at the root.';

  @override
  String get frontMatterHelper => 'Leave empty to let your site\'s _config.yml defaults apply (recommended).';

  @override
  String get layoutLabel => 'Layout';

  @override
  String get defaultCategoriesLabel => 'Default Categories';

  @override
  String get defaultCategoriesHint => 'blog, notes (comma separated)';

  @override
  String get defaultTagsLabel => 'Default Tags';

  @override
  String get defaultTagsHint => 'jekyll, writing (comma separated)';

  @override
  String get saveConfiguration => 'Save Configuration';

  @override
  String get useDifferentAccount => 'Use different account';

  @override
  String get newFolderDialogTitle => 'New Folder';

  @override
  String get newFolderHint => '_wiki or docs/notes';

  @override
  String get newFolderHelpRoot => 'Created inside the repository root - GitHub creates the folder with your first upload.';

  @override
  String newFolderHelpPath(String path) {
    return 'Created inside /$path - GitHub creates the folder with your first upload.';
  }

  @override
  String get useFolder => 'Use Folder';

  @override
  String get enterValidFolderName => 'Enter a valid folder name';

  @override
  String get selectFolderTitle => 'Select Folder';

  @override
  String get refreshFoldersTooltip => 'Refresh folders';

  @override
  String get newFolderTooltip => 'New folder';

  @override
  String get goUpTooltip => 'Go up';

  @override
  String get noSubfolders => 'No subfolders';

  @override
  String get noSubfoldersBody => 'This folder has no subfolders.\nYou can select this folder or go back.';

  @override
  String get selectedPathLabel => 'Selected path:';

  @override
  String get repositoryRootLabel => '(repository root)';

  @override
  String get selectThisFolder => 'Select This Folder';

  @override
  String get unpublishedEditsTitle => 'Unpublished Edits';

  @override
  String unpublishedEditsBody(String timeAgo) {
    return 'You have unpublished edits for this post (last modified $timeAgo).';
  }

  @override
  String get discardEdits => 'Discard edits';

  @override
  String get resumeMyEdits => 'Resume my edits';

  @override
  String get searchPostsHint => 'Search posts and drafts...';

  @override
  String get tabPublished => 'Published';

  @override
  String get tabDrafts => 'Drafts';

  @override
  String get blogFallbackTitle => 'Blog';

  @override
  String get searchPostsTooltip => 'Search posts';

  @override
  String get refreshPostsTooltip => 'Refresh posts';

  @override
  String get moreOptionsTooltip => 'More options';

  @override
  String get menuOpenSite => 'Open site';

  @override
  String get menuChangeRepository => 'Change Repository';

  @override
  String get themeLabel => 'Theme';

  @override
  String get aboutLabel => 'About';

  @override
  String get logoutLabel => 'Logout';

  @override
  String get themeSystemDefault => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get logoutDialogTitle => 'Logout?';

  @override
  String get logoutDialogBody => 'This removes your token and clears all cached posts, drafts, and images from this device.';

  @override
  String syncingProgress(int done, int total) {
    return 'Syncing $done of $total...';
  }

  @override
  String get loadingPosts => 'Loading posts...';

  @override
  String get failedToLoadPosts => 'Failed to load posts';

  @override
  String couldNotOpenUrl(String url) {
    return 'Could not open $url';
  }

  @override
  String get deleteFromGitHubTitle => 'Delete from GitHub?';

  @override
  String deleteFromGitHubBody(String fileName) {
    return 'This deletes \"$fileName\" from the repository. This cannot be undone from the app.';
  }

  @override
  String deletedFile(String fileName) {
    return 'Deleted $fileName';
  }

  @override
  String get thisPostFallback => 'this post';

  @override
  String get thisDraftFallback => 'this draft';

  @override
  String get promoteDialogTitle => 'Promote to post?';

  @override
  String promoteDialogBody(String fileName, String draftsPath, String contentDir) {
    return 'This moves \"$fileName\" from $draftsPath to $contentDir and publishes it with today\'s date.';
  }

  @override
  String get promoteAction => 'Promote';

  @override
  String get draftPromotedToPost => 'Draft promoted to post';

  @override
  String get syncFailedShowingCached => 'Sync failed - showing cached data';

  @override
  String lastSyncedCaption(String timeAgo) {
    return 'Last synced $timeAgo';
  }

  @override
  String queueWaitingCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts waiting to publish',
      one: '1 post waiting to publish',
    );
    return '$_temp0';
  }

  @override
  String queueFailedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count queued posts failed',
      one: '1 queued post failed',
    );
    return '$_temp0';
  }

  @override
  String get publishNow => 'Publish now';

  @override
  String failedQueueItemSemantics(String title) {
    return 'Failed to publish \"$title\". Tap to reopen it in the editor';
  }

  @override
  String couldNotPublishTapToEdit(String title) {
    return 'Couldn\'t publish \"$title\" - tap to edit';
  }

  @override
  String get newPostAction => 'New Post';

  @override
  String draftsOnGitHubSection(String draftsPath) {
    return 'On GitHub ($draftsPath)';
  }

  @override
  String get draftsOnDeviceSection => 'On this device';

  @override
  String get noDraftsYet => 'No drafts yet';

  @override
  String get draftsEmptyBody => 'Your unsaved posts will appear here';

  @override
  String get noPostsMatch => 'No posts match';

  @override
  String get tryDifferentSearch => 'Try a different search';

  @override
  String get editingStatus => 'Editing';

  @override
  String get newStatus => 'New';

  @override
  String get draftStatusEditingSemantics => 'Draft status: editing an existing post';

  @override
  String get draftStatusNewSemantics => 'Draft status: new post';

  @override
  String get deleteDraftTooltip => 'Delete draft';

  @override
  String get deleteDraftDialogTitle => 'Delete Draft?';

  @override
  String deleteDraftDialogBody(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get draftDeleted => 'Draft deleted';

  @override
  String get timeAgoJustNow => 'just now';

  @override
  String timeAgoMinutes(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeAgoHours(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeAgoDays(int days) {
    return '${days}d ago';
  }

  @override
  String get draftOnGitHubSemantics => 'Draft on GitHub';

  @override
  String get draftBadge => 'Draft';

  @override
  String get postActionsTooltip => 'Post actions';

  @override
  String get viewPostAction => 'View post';

  @override
  String get promoteToPostAction => 'Promote to post';

  @override
  String get deleteFromGitHubAction => 'Delete from GitHub';

  @override
  String get noPostsYet => 'No Posts Yet';

  @override
  String emptyPostsBody(String folder) {
    return 'Your $folder folder is empty.\nTap the button below to create your first post!';
  }

  @override
  String get tapPlusToWrite => 'Tap the + button to start writing';

  @override
  String get draftSavedSnack => 'Draft saved';

  @override
  String get pleaseEnterTitle => 'Please enter a title';

  @override
  String get postPublishedSuccess => 'Post published successfully!';

  @override
  String draftSavedToGitHub(String filename) {
    return 'Draft saved to GitHub: $filename';
  }

  @override
  String postCreated(String filename) {
    return 'Post created: $filename';
  }

  @override
  String get postUpdatedSuccess => 'Post updated successfully!';

  @override
  String get failedToPublishGeneric => 'Failed to publish';

  @override
  String get queuedWillPublishWhenOnline => 'Queued - will publish when back online';

  @override
  String get offlineDialogTitle => 'You appear to be offline';

  @override
  String get offlineDialogBody => 'GitHub cannot be reached right now. This post can be queued and published automatically when the connection returns.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discardAction => 'Discard';

  @override
  String get queueAndPublishWhenOnline => 'Queue and publish when online';

  @override
  String get conflictDialogTitle => 'Post changed on GitHub';

  @override
  String get conflictDialogBody => 'This post was changed on GitHub after you opened it. Overwrite it with your version, or keep both to review?';

  @override
  String get keepBoth => 'Keep both';

  @override
  String get overwriteWithMyVersion => 'Overwrite with my version';

  @override
  String get savedButRemoteNotLocated => 'Your version was saved to drafts, but the GitHub version could not be located';

  @override
  String savedButRemoteNotLoaded(String error) {
    return 'Your version was saved to drafts, but the GitHub version could not be loaded: $error';
  }

  @override
  String get savedNowShowingRemote => 'Your version was saved to drafts - now showing the GitHub version';

  @override
  String get uploadsTakingTooLong => 'Uploads are taking too long - try publishing again in a moment';

  @override
  String get mediaStillUploadingTitle => 'Media still uploading';

  @override
  String pendingUploadsBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files in this post are still uploading. Wait for them to finish?',
      one: '1 file in this post is still uploading. Wait for it to finish?',
    );
    return '$_temp0';
  }

  @override
  String get publishAnyway => 'Publish anyway';

  @override
  String get waitAction => 'Wait';

  @override
  String get mediaUploadsFailedTitle => 'Media uploads failed';

  @override
  String failedUploadsBody(String files) {
    return 'These files failed to upload:\n\n$files\n\nPublishing now would leave broken media in the post.';
  }

  @override
  String get retryUploads => 'Retry uploads';

  @override
  String get waitingForUploads => 'Waiting for uploads...';

  @override
  String get galleryOption => 'Gallery';

  @override
  String get cameraOption => 'Camera';

  @override
  String get uploadingImage => 'Uploading image...';

  @override
  String failedToAddImage(String error) {
    return 'Failed to add image: $error';
  }

  @override
  String get compressingVideo => 'Compressing video...';

  @override
  String get uploadingVideo => 'Uploading video...';

  @override
  String get editPostTitle => 'Edit Post';

  @override
  String get postSettingsLabel => 'Post settings';

  @override
  String get publishAction => 'Publish';

  @override
  String get morePublishOptionsTooltip => 'More publish options';

  @override
  String get saveAsDraftOnGitHub => 'Save as draft on GitHub';

  @override
  String get statusSaving => 'Saving...';

  @override
  String get statusSaved => 'Saved';

  @override
  String get statusError => 'Error';

  @override
  String draftStatusSemantics(String status) {
    return 'Draft status: $status';
  }

  @override
  String get tabWrite => 'Write';

  @override
  String get tabPreview => 'Preview';

  @override
  String get titleLabel => 'Title';

  @override
  String get enterPostTitleHint => 'Enter post title...';

  @override
  String get titleLockedTooltip => 'Title cannot be changed for existing posts';

  @override
  String get titleLockedNote => 'Title is locked for existing posts';

  @override
  String get contentLabel => 'Content';

  @override
  String get undoTooltip => 'Undo';

  @override
  String get redoTooltip => 'Redo';

  @override
  String get hideKeyboardTooltip => 'Hide keyboard';

  @override
  String get addImageTooltip => 'Add image';

  @override
  String get addVideoTooltip => 'Add video';

  @override
  String get addYouTubeTooltip => 'Add YouTube video';

  @override
  String get addYouTubeTitle => 'Add YouTube Video';

  @override
  String get youTubeLinkHint => 'Paste a YouTube link';

  @override
  String get notAYouTubeLink => 'Not a YouTube video link';

  @override
  String get insertAction => 'Insert';

  @override
  String get markdownHelpTooltip => 'Markdown help';

  @override
  String get bodyHint => 'Start writing your post...\n\nTip: Use Markdown for formatting!';

  @override
  String get nothingToPreviewYet => 'Nothing to preview yet';

  @override
  String get switchToWriteTab => 'Switch to the Write tab and add some content';

  @override
  String get imageFallbackAlt => 'Image';

  @override
  String get videoFallbackLabel => 'video';

  @override
  String get uploadingEllipsis => 'Uploading...';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String retryUploadOf(String filename) {
    return 'Retry upload of $filename';
  }

  @override
  String get markdownQuickReference => 'Markdown Quick Reference';

  @override
  String get mdLargeHeading => 'Large heading';

  @override
  String get mdMediumHeading => 'Medium heading';

  @override
  String get mdBoldText => 'Bold text';

  @override
  String get mdItalicText => 'Italic text';

  @override
  String get mdHyperlink => 'Hyperlink';

  @override
  String get mdImage => 'Image';

  @override
  String get mdBulletList => 'Bullet list';

  @override
  String get mdNumberedList => 'Numbered list';

  @override
  String get mdBlockQuote => 'Block quote';

  @override
  String get mdInlineCode => 'Inline code';

  @override
  String get publicationDateLabel => 'Publication date';

  @override
  String get currentPostDateHint => 'Current post date - tap to change';

  @override
  String get dateSetAutomaticallyHint => 'Set automatically when you publish - tap to override';

  @override
  String get layoutEmptyHint => 'Leave empty to use the site default';

  @override
  String get categoriesLabel => 'Categories';

  @override
  String get addCategoryHint => 'Add a category...';

  @override
  String get tagsLabel => 'Tags';

  @override
  String get addTagHint => 'Add a tag...';

  @override
  String get customFieldsLabel => 'Custom fields';

  @override
  String get customFieldsPreservedNote => 'These fields are preserved as-is when you publish';

  @override
  String get aboutAppName => 'Jekyll Press';

  @override
  String get versionLoading => 'Version …';

  @override
  String versionLabel(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutSectionTitle => 'About Jekyll Press';

  @override
  String get aboutSectionBody => 'Jekyll Press is a mobile-first CMS for any Jekyll blog hosted on GitHub. Write, edit, and publish posts directly from your phone — no laptop, no git commands.\n\nBuilt with Flutter and powered by the GitHub REST API, it works with your repository as-is: your posts folder, drafts, collections, branch, and front matter conventions are all configurable.';

  @override
  String get motivationTitle => 'Motivation';

  @override
  String get motivationBody => 'As a developer who blogs on GitHub Pages, I often found inspiration for new posts while away from my computer. Jekyll Press was born from the need to capture and publish those ideas immediately, without waiting to get back to a desktop.\n\nThe goal is simple: make mobile blogging on Jekyll as seamless as writing in any native notes app.';

  @override
  String get howToUseTitle => 'How to Use';

  @override
  String get howToUseBody => '1. Tap \"Sign in with GitHub\" and approve the code on github.com — or paste a Personal Access Token instead\n2. Select your Jekyll blog repository and branch\n3. Confirm the detected posts, drafts, and assets folders\n4. Start writing! Tap the + button to create a new post\n5. Add photos and videos straight from your gallery or camera\n6. Use the Preview tab to see your formatted markdown\n7. Hit Publish to push directly to GitHub — or queue it while offline';

  @override
  String get limitationsTitle => 'Limitations';

  @override
  String get limitationsBody => '• Android only\n• \"Sign in with GitHub\" asks for the repo scope: read and write access to your repositories, public and private. It is the narrowest scope that lets an OAuth app edit files in a private repo. JekyllPress only touches the repository you configure, and you can revoke access any time at github.com → Settings → Applications → Authorized OAuth Apps. For access to a single repository, sign in with a fine-grained Personal Access Token instead\n• Published posts cannot be renamed in-app (the filename dictates the permalink; renames would break links)\n• Videos are re-encoded with the short edge capped at 640px, and uploads are capped at 25MB\n• Repository files are edited one at a time via the GitHub API (no multi-file commits or merges)';

  @override
  String get privacySectionTitle => 'Privacy';

  @override
  String get privacySectionBody => 'Everything stays between your device and your own GitHub repository. Your token lives in Android\'s encrypted, Keystore-backed storage; there are no analytics and no third-party servers. Logging out deletes the token from this device and wipes all cached content — it does not revoke the token on GitHub, so revoke it there too if you want the authorization gone.';

  @override
  String get readPrivacyPolicy => 'Read the privacy policy';

  @override
  String get openSourceTitle => 'Open Source';

  @override
  String get openSourceBody => 'Jekyll Press is open source under the MIT License. Found a bug or have a feature request? Head over to GitHub to:\n\n• Report issues\n• Request features\n• Contribute code\n• Star the repo ⭐';

  @override
  String get viewOnGitHub => 'View on GitHub';

  @override
  String get createdByLabel => 'Created by';

  @override
  String get creatorCardSemantics => 'Open the creator\'s website, www.gapp.in';

  @override
  String get mitLicenseTitle => 'MIT License';

  @override
  String linkCopiedSnack(String url) {
    return 'Link copied: $url';
  }

  @override
  String get oneTimeSetupInstallHint => 'Last step: on your new app\'s page, open \"Install App\" and give it access to your blog repository.';

  @override
  String get appNameTakenHint => 'If GitHub says the name is taken, add something to make it unique.';

  @override
  String get changeClientId => 'Change Client ID';
}
