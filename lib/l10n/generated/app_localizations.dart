import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en')
  ];

  /// Application name shown in the launcher/task switcher and splash screen. Usually not translated.
  ///
  /// In en, this message translates to:
  /// **'JekyllPress'**
  String get appTitle;

  /// Generic cancel button in dialogs and sheets
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Generic delete confirmation button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Generic retry button after a failure
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Tooltip of the back navigation arrow
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Placeholder title for a draft or post without a title
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get commonUntitled;

  /// Snackbar action that opens the published post in the browser
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// Subtitle under the app name on the login screen
  ///
  /// In en, this message translates to:
  /// **'Your mobile CMS for Jekyll blogs.\nConnect with your GitHub account.'**
  String get loginTagline;

  /// Snackbar when no browser could be launched; the URL was copied to the clipboard instead
  ///
  /// In en, this message translates to:
  /// **'Could not open browser - link copied: {url}'**
  String couldNotOpenBrowserLinkCopied(String url);

  /// Snackbar when the Client ID field of the fallback setup card is submitted empty
  ///
  /// In en, this message translates to:
  /// **'Paste the Client ID from your GitHub App'**
  String get pasteClientIdPrompt;

  /// Primary sign-in button and title of the device-flow bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Sign in with GitHub'**
  String get signInWithGitHub;

  /// Title of the card asking for a GitHub App Client ID. Only shown in builds that ship no Client ID of their own
  ///
  /// In en, this message translates to:
  /// **'One-time setup'**
  String get oneTimeSetupTitle;

  /// Explanation in the one-time GitHub App setup card, shown only in builds with no bundled Client ID
  ///
  /// In en, this message translates to:
  /// **'This build ships without a Client ID, so signing in without a token needs a free GitHub App on your account. The button below opens GitHub with everything pre-filled - you only have to tick \"Enable Device Flow\", then press Create GitHub App. Copy the Client ID it shows you into the box below.'**
  String get oneTimeSetupBody;

  /// Button opening github.com's new-app registration page
  ///
  /// In en, this message translates to:
  /// **'Open GitHub App setup'**
  String get openGitHubAppSetup;

  /// Label of the GitHub App Client ID text field
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get clientIdLabel;

  /// Button that stores the Client ID and starts the device flow
  ///
  /// In en, this message translates to:
  /// **'Save & sign in'**
  String get saveAndSignIn;

  /// Toggle revealing the Personal Access Token login section
  ///
  /// In en, this message translates to:
  /// **'Use a Personal Access Token instead'**
  String get usePatInstead;

  /// Label of the token text field
  ///
  /// In en, this message translates to:
  /// **'Personal Access Token'**
  String get patLabel;

  /// Tooltip of the visibility toggle when the token is hidden
  ///
  /// In en, this message translates to:
  /// **'Show token'**
  String get showTokenTooltip;

  /// Tooltip of the visibility toggle when the token is visible
  ///
  /// In en, this message translates to:
  /// **'Hide token'**
  String get hideTokenTooltip;

  /// Validation error when the token field is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter your GitHub token'**
  String get enterTokenValidation;

  /// Warning under the token field when the input doesn't match known GitHub token formats
  ///
  /// In en, this message translates to:
  /// **'This doesn\'t look like a GitHub token - double-check it. You can still try connecting.'**
  String get tokenFormatWarning;

  /// Button submitting the Personal Access Token
  ///
  /// In en, this message translates to:
  /// **'Connect with token'**
  String get connectWithToken;

  /// Link button opening GitHub's token creation page
  ///
  /// In en, this message translates to:
  /// **'Create a token on GitHub'**
  String get createTokenOnGitHub;

  /// Generic device-flow failure message in the sign-in sheet
  ///
  /// In en, this message translates to:
  /// **'GitHub sign-in failed - try again'**
  String get deviceSignInFailed;

  /// Tooltip of the X button in the device-flow sheet
  ///
  /// In en, this message translates to:
  /// **'Cancel sign-in'**
  String get cancelSignInTooltip;

  /// Progress label while the device code is being requested
  ///
  /// In en, this message translates to:
  /// **'Requesting a code from GitHub...'**
  String get requestingCodeFromGitHub;

  /// Instruction above the device-flow user code
  ///
  /// In en, this message translates to:
  /// **'Enter this code on GitHub:'**
  String get enterCodeOnGitHub;

  /// Caption confirming the device code was auto-copied
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Button opening GitHub's device login page. The URL itself should not be translated.
  ///
  /// In en, this message translates to:
  /// **'Open github.com/login/device'**
  String get openGitHubDeviceLogin;

  /// Progress label while polling for the user to authorize on GitHub
  ///
  /// In en, this message translates to:
  /// **'Waiting for you to authorize...'**
  String get waitingForAuthorization;

  /// Heading of the repository configuration screen
  ///
  /// In en, this message translates to:
  /// **'Configure Your Blog'**
  String get configTitle;

  /// Subtitle under the configuration heading
  ///
  /// In en, this message translates to:
  /// **'Connect your Jekyll repository and tune how posts are published.'**
  String get configTagline;

  /// Shows the authenticated GitHub username
  ///
  /// In en, this message translates to:
  /// **'Logged in as @{username}'**
  String loggedInAs(String username);

  /// Uppercase section title on the config screen
  ///
  /// In en, this message translates to:
  /// **'REPOSITORY'**
  String get sectionRepository;

  /// Uppercase section title on the config screen
  ///
  /// In en, this message translates to:
  /// **'BRANCH'**
  String get sectionBranch;

  /// Uppercase section title on the config screen
  ///
  /// In en, this message translates to:
  /// **'CONTENT'**
  String get sectionContent;

  /// Uppercase section title on the config screen
  ///
  /// In en, this message translates to:
  /// **'SITE'**
  String get sectionSite;

  /// Uppercase section title on the config screen. 'Front matter' is Jekyll terminology.
  ///
  /// In en, this message translates to:
  /// **'FRONT MATTER DEFAULTS'**
  String get sectionFrontMatterDefaults;

  /// Snackbar when the manual repository input is not a valid owner/name pair
  ///
  /// In en, this message translates to:
  /// **'Enter the repository as owner/name'**
  String get enterRepoAsOwnerName;

  /// Snackbar when browsing folders before a repository is chosen
  ///
  /// In en, this message translates to:
  /// **'Please select a repository first'**
  String get selectRepositoryFirstSnack;

  /// Snackbar when the repo root is picked as an additional content folder
  ///
  /// In en, this message translates to:
  /// **'The repository root cannot be a content folder'**
  String get rootCannotBeContentFolder;

  /// Title of the confirmation dialog when switching to a different repo/branch
  ///
  /// In en, this message translates to:
  /// **'Change Repository?'**
  String get changeRepositoryDialogTitle;

  /// Body of the repo-switch confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Drafts and cached posts are specific to the current repository and branch, and will be removed. This cannot be undone.'**
  String get changeRepositoryDialogBody;

  /// Destructive confirm button of the repo-switch dialog
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changeAction;

  /// Validation/snackbar message when saving without a repository selected
  ///
  /// In en, this message translates to:
  /// **'Please select a repository'**
  String get pleaseSelectRepository;

  /// Snackbar when saving the configuration fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSaveConfig(String error);

  /// Helper text under the repository dropdown
  ///
  /// In en, this message translates to:
  /// **'Choose the repository that contains your Jekyll blog.'**
  String get chooseRepoHelper;

  /// Progress label while the repository list loads
  ///
  /// In en, this message translates to:
  /// **'Loading repositories...'**
  String get loadingRepositories;

  /// Inline error when the repository list could not be fetched
  ///
  /// In en, this message translates to:
  /// **'Failed to load repos: {error}'**
  String failedToLoadRepos(String error);

  /// Hint of the repository dropdown
  ///
  /// In en, this message translates to:
  /// **'Select your blog repository'**
  String get selectBlogRepositoryHint;

  /// Badge on private repositories in the dropdown
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateBadge;

  /// Link collapsing the manual owner/name entry field
  ///
  /// In en, this message translates to:
  /// **'Hide manual entry'**
  String get hideManualEntry;

  /// Link revealing the manual owner/name entry field
  ///
  /// In en, this message translates to:
  /// **'Can\'t see your repo? Enter owner/name manually'**
  String get manualEntryPrompt;

  /// Badge confirming a manually entered repository is in use
  ///
  /// In en, this message translates to:
  /// **'Using {repo}'**
  String usingRepo(String repo);

  /// Banner while the app verifies the repo looks like a Jekyll site
  ///
  /// In en, this message translates to:
  /// **'Checking for a Jekyll site...'**
  String get checkingForJekyllSite;

  /// Banner when the repo looks like a Jekyll site
  ///
  /// In en, this message translates to:
  /// **'Jekyll site detected'**
  String get jekyllSiteDetected;

  /// Banner when the Jekyll check was inconclusive
  ///
  /// In en, this message translates to:
  /// **'Could not verify this is a Jekyll site - you can continue anyway'**
  String get jekyllCouldNotVerify;

  /// Banner when the repo has neither _config.yml nor the posts folder. '_config.yml' is a filename and must not be translated.
  ///
  /// In en, this message translates to:
  /// **'This does not look like a Jekyll repo (no _config.yml or {postsPath})'**
  String notJekyllRepo(String postsPath);

  /// Hint when zero repos are visible to a device-flow session
  ///
  /// In en, this message translates to:
  /// **'No repositories found for this account. If you signed in with your own GitHub App, it only sees repositories it is installed on - install it on your blog repo, then refresh. Otherwise, enter owner/repo manually below.'**
  String get noReposFoundDeviceAuth;

  /// Hint when the account has no repositories
  ///
  /// In en, this message translates to:
  /// **'No repositories found for this account.'**
  String get noReposFoundForAccount;

  /// Button opening github.com/settings/installations
  ///
  /// In en, this message translates to:
  /// **'Open GitHub App installations'**
  String get openGitHubAppInstallations;

  /// Placeholder in the branch section before a repository is chosen
  ///
  /// In en, this message translates to:
  /// **'Select a repository first'**
  String get selectARepositoryFirst;

  /// Progress label while the branch list loads
  ///
  /// In en, this message translates to:
  /// **'Loading branches...'**
  String get loadingBranches;

  /// Inline error when the branch list could not be fetched; a fallback branch is used
  ///
  /// In en, this message translates to:
  /// **'Failed to load branches - using \"{branch}\"'**
  String failedToLoadBranches(String branch);

  /// Helper text under the branch dropdown
  ///
  /// In en, this message translates to:
  /// **'Branch posts are read from and published to.'**
  String get branchHelper;

  /// Badge on the repository's default branch in the dropdown
  ///
  /// In en, this message translates to:
  /// **'default'**
  String get defaultBranchBadge;

  /// Label of the posts directory field
  ///
  /// In en, this message translates to:
  /// **'Posts Folder'**
  String get postsFolderLabel;

  /// Helper text under the posts directory field
  ///
  /// In en, this message translates to:
  /// **'Folder your published Jekyll posts live in.'**
  String get postsFolderHelper;

  /// Label of the drafts directory field
  ///
  /// In en, this message translates to:
  /// **'Drafts Folder'**
  String get draftsFolderLabel;

  /// Helper text under the drafts directory field
  ///
  /// In en, this message translates to:
  /// **'Folder Jekyll drafts are saved to.'**
  String get draftsFolderHelper;

  /// Label of the extra Jekyll collections editor
  ///
  /// In en, this message translates to:
  /// **'Additional Content Folders'**
  String get additionalContentFoldersLabel;

  /// Chip that adds another content folder
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get addFolder;

  /// Helper text under the content folders editor
  ///
  /// In en, this message translates to:
  /// **'Jekyll collections you also publish to (e.g. _wiki, _projects). Switch between them from the dashboard.'**
  String get additionalContentFoldersHelper;

  /// Label of the image upload directory field
  ///
  /// In en, this message translates to:
  /// **'Image Assets Path'**
  String get imageAssetsPathLabel;

  /// Helper text under the image assets field
  ///
  /// In en, this message translates to:
  /// **'Folder where images will be uploaded. Tap the folder icon to browse.'**
  String get imageAssetsPathHelper;

  /// Validation error for an empty path field; the placeholder is the lowercase field label
  ///
  /// In en, this message translates to:
  /// **'Please enter the {field}'**
  String pathFieldRequired(String field);

  /// Validation error for a path that normalizes to nothing
  ///
  /// In en, this message translates to:
  /// **'Invalid path'**
  String get invalidPath;

  /// Label of the public site URL field
  ///
  /// In en, this message translates to:
  /// **'Site URL'**
  String get siteUrlLabel;

  /// Helper text under the site URL field
  ///
  /// In en, this message translates to:
  /// **'Public URL of your published site. Pre-filled from the GitHub Pages convention - change it if you use a custom domain.'**
  String get siteUrlHelper;

  /// Label of the Jekyll baseurl field
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrlLabel;

  /// Helper text under the base URL field. 'baseurl' is a Jekyll config key and must not be translated.
  ///
  /// In en, this message translates to:
  /// **'Project pages are served under /<repo> (e.g. https://user.github.io/blog needs baseurl /blog) - image links are prefixed with it. Leave empty for user/org sites and custom domains served at the root.'**
  String get baseUrlHelper;

  /// Helper text above the front matter default fields. '_config.yml' is a filename.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to let your site\'s _config.yml defaults apply (recommended).'**
  String get frontMatterHelper;

  /// Label of the Jekyll layout field (config screen and post settings sheet)
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layoutLabel;

  /// Label of the default categories field
  ///
  /// In en, this message translates to:
  /// **'Default Categories'**
  String get defaultCategoriesLabel;

  /// Hint of the default categories field
  ///
  /// In en, this message translates to:
  /// **'blog, notes (comma separated)'**
  String get defaultCategoriesHint;

  /// Label of the default tags field
  ///
  /// In en, this message translates to:
  /// **'Default Tags'**
  String get defaultTagsLabel;

  /// Hint of the default tags field
  ///
  /// In en, this message translates to:
  /// **'jekyll, writing (comma separated)'**
  String get defaultTagsHint;

  /// Primary save button on the config screen
  ///
  /// In en, this message translates to:
  /// **'Save Configuration'**
  String get saveConfiguration;

  /// Logout link on the first-run config screen
  ///
  /// In en, this message translates to:
  /// **'Use different account'**
  String get useDifferentAccount;

  /// Title of the new-folder dialog in the folder browser
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get newFolderDialogTitle;

  /// Hint of the new folder name field. Example folder names; keep as technical examples.
  ///
  /// In en, this message translates to:
  /// **'_wiki or docs/notes'**
  String get newFolderHint;

  /// Helper text in the new-folder dialog when at the repository root
  ///
  /// In en, this message translates to:
  /// **'Created inside the repository root - GitHub creates the folder with your first upload.'**
  String get newFolderHelpRoot;

  /// Helper text in the new-folder dialog inside a subfolder
  ///
  /// In en, this message translates to:
  /// **'Created inside /{path} - GitHub creates the folder with your first upload.'**
  String newFolderHelpPath(String path);

  /// Confirm button of the new-folder dialog
  ///
  /// In en, this message translates to:
  /// **'Use Folder'**
  String get useFolder;

  /// Snackbar when the typed folder name is invalid
  ///
  /// In en, this message translates to:
  /// **'Enter a valid folder name'**
  String get enterValidFolderName;

  /// Title of the repository folder browser
  ///
  /// In en, this message translates to:
  /// **'Select Folder'**
  String get selectFolderTitle;

  /// Reloads the folder list; a mouse cannot pull-to-refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh folders'**
  String get refreshFoldersTooltip;

  /// Tooltip of the new-folder icon button
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolderTooltip;

  /// Tooltip of the navigate-to-parent-folder button
  ///
  /// In en, this message translates to:
  /// **'Go up'**
  String get goUpTooltip;

  /// Empty-state title when the current folder has no subfolders
  ///
  /// In en, this message translates to:
  /// **'No subfolders'**
  String get noSubfolders;

  /// Empty-state body in the folder browser
  ///
  /// In en, this message translates to:
  /// **'This folder has no subfolders.\nYou can select this folder or go back.'**
  String get noSubfoldersBody;

  /// Caption above the currently selected folder path
  ///
  /// In en, this message translates to:
  /// **'Selected path:'**
  String get selectedPathLabel;

  /// Shown as the selected path when the repository root is selected
  ///
  /// In en, this message translates to:
  /// **'(repository root)'**
  String get repositoryRootLabel;

  /// Confirm button of the folder browser
  ///
  /// In en, this message translates to:
  /// **'Select This Folder'**
  String get selectThisFolder;

  /// Title of the dialog offering to resume a local edit draft
  ///
  /// In en, this message translates to:
  /// **'Unpublished Edits'**
  String get unpublishedEditsTitle;

  /// Body of the resume-draft dialog
  ///
  /// In en, this message translates to:
  /// **'You have unpublished edits for this post (last modified {timeAgo}).'**
  String unpublishedEditsBody(String timeAgo);

  /// Destructive button dropping the local edit draft
  ///
  /// In en, this message translates to:
  /// **'Discard edits'**
  String get discardEdits;

  /// Button resuming the local edit draft
  ///
  /// In en, this message translates to:
  /// **'Resume my edits'**
  String get resumeMyEdits;

  /// Hint of the dashboard search field
  ///
  /// In en, this message translates to:
  /// **'Search posts and drafts...'**
  String get searchPostsHint;

  /// Dashboard tab with posts already on GitHub
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get tabPublished;

  /// Dashboard tab with local and remote drafts
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get tabDrafts;

  /// Dashboard title fallback when no repository name is available
  ///
  /// In en, this message translates to:
  /// **'Blog'**
  String get blogFallbackTitle;

  /// Tooltip of the search toggle button
  ///
  /// In en, this message translates to:
  /// **'Search posts'**
  String get searchPostsTooltip;

  /// Tooltip of the refresh button
  ///
  /// In en, this message translates to:
  /// **'Refresh posts'**
  String get refreshPostsTooltip;

  /// Tooltip of the overflow menu button
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsTooltip;

  /// Overflow menu item opening the published site
  ///
  /// In en, this message translates to:
  /// **'Open site'**
  String get menuOpenSite;

  /// Overflow menu item opening the repository settings
  ///
  /// In en, this message translates to:
  /// **'Change Repository'**
  String get menuChangeRepository;

  /// Overflow menu item and dialog title for the theme picker
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// Overflow menu item and app bar title of the About screen
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutLabel;

  /// Overflow menu item and confirm button that signs the user out
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutLabel;

  /// Theme option following the Android system setting
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystemDefault;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Title of the logout confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Logout?'**
  String get logoutDialogTitle;

  /// Body of the logout confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This removes your token and clears all cached posts, drafts, and images from this device.'**
  String get logoutDialogBody;

  /// Progress caption while changed post bodies are fetched
  ///
  /// In en, this message translates to:
  /// **'Syncing {done} of {total}...'**
  String syncingProgress(int done, int total);

  /// Progress label on the dashboard while posts load
  ///
  /// In en, this message translates to:
  /// **'Loading posts...'**
  String get loadingPosts;

  /// Error-state title when posts could not be loaded and no cache exists
  ///
  /// In en, this message translates to:
  /// **'Failed to load posts'**
  String get failedToLoadPosts;

  /// Snackbar when a URL could not be opened in a browser
  ///
  /// In en, this message translates to:
  /// **'Could not open {url}'**
  String couldNotOpenUrl(String url);

  /// Title of the remote-delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete from GitHub?'**
  String get deleteFromGitHubTitle;

  /// Body of the remote-delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This deletes \"{fileName}\" from the repository. This cannot be undone from the app.'**
  String deleteFromGitHubBody(String fileName);

  /// Snackbar after a file was deleted from GitHub
  ///
  /// In en, this message translates to:
  /// **'Deleted {fileName}'**
  String deletedFile(String fileName);

  /// Fallback used in place of a filename when a post has none
  ///
  /// In en, this message translates to:
  /// **'this post'**
  String get thisPostFallback;

  /// Fallback used in place of a filename when a draft has none
  ///
  /// In en, this message translates to:
  /// **'this draft'**
  String get thisDraftFallback;

  /// Title of the promote-draft confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Promote to post?'**
  String get promoteDialogTitle;

  /// Body of the promote-draft confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'This moves \"{fileName}\" from {draftsPath} to {contentDir} and publishes it with today\'s date.'**
  String promoteDialogBody(String fileName, String draftsPath, String contentDir);

  /// Confirm button of the promote-draft dialog
  ///
  /// In en, this message translates to:
  /// **'Promote'**
  String get promoteAction;

  /// Snackbar after a remote draft was promoted
  ///
  /// In en, this message translates to:
  /// **'Draft promoted to post'**
  String get draftPromotedToPost;

  /// Banner when a sync fails but cached posts are shown
  ///
  /// In en, this message translates to:
  /// **'Sync failed - showing cached data'**
  String get syncFailedShowingCached;

  /// Caption above the posts list with the time of the last successful sync
  ///
  /// In en, this message translates to:
  /// **'Last synced {timeAgo}'**
  String lastSyncedCaption(String timeAgo);

  /// Offline-queue banner label for posts waiting to publish
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 post waiting to publish} other{{count} posts waiting to publish}}'**
  String queueWaitingCount(num count);

  /// Offline-queue banner label when queued posts ran out of retries
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 queued post failed} other{{count} queued posts failed}}'**
  String queueFailedCount(num count);

  /// Button that processes the offline publish queue immediately
  ///
  /// In en, this message translates to:
  /// **'Publish now'**
  String get publishNow;

  /// Accessibility label of a failed queue row
  ///
  /// In en, this message translates to:
  /// **'Failed to publish \"{title}\". Tap to reopen it in the editor'**
  String failedQueueItemSemantics(String title);

  /// Failed queue row label; tapping reopens the post in the editor
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t publish \"{title}\" - tap to edit'**
  String couldNotPublishTapToEdit(String title);

  /// FAB label on the dashboard and editor title for a new post
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get newPostAction;

  /// Drafts tab section header for drafts living in the repository
  ///
  /// In en, this message translates to:
  /// **'On GitHub ({draftsPath})'**
  String draftsOnGitHubSection(String draftsPath);

  /// Drafts tab section header for device-local drafts
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get draftsOnDeviceSection;

  /// Empty-state title of the Drafts tab
  ///
  /// In en, this message translates to:
  /// **'No drafts yet'**
  String get noDraftsYet;

  /// Empty-state body of the Drafts tab
  ///
  /// In en, this message translates to:
  /// **'Your unsaved posts will appear here'**
  String get draftsEmptyBody;

  /// Empty-state title when a search matches nothing
  ///
  /// In en, this message translates to:
  /// **'No posts match'**
  String get noPostsMatch;

  /// Empty-state body when a search matches nothing
  ///
  /// In en, this message translates to:
  /// **'Try a different search'**
  String get tryDifferentSearch;

  /// Badge/status for a draft that edits an existing post, and the editor's unsaved-changes status
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get editingStatus;

  /// Badge for a draft of a brand-new post
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newStatus;

  /// Accessibility label of the Editing badge
  ///
  /// In en, this message translates to:
  /// **'Draft status: editing an existing post'**
  String get draftStatusEditingSemantics;

  /// Accessibility label of the New badge
  ///
  /// In en, this message translates to:
  /// **'Draft status: new post'**
  String get draftStatusNewSemantics;

  /// Tooltip of the delete button on a local draft card
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get deleteDraftTooltip;

  /// Title of the delete-draft confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Draft?'**
  String get deleteDraftDialogTitle;

  /// Body of the delete-draft confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String deleteDraftDialogBody(String title);

  /// Snackbar after a local draft was deleted
  ///
  /// In en, this message translates to:
  /// **'Draft deleted'**
  String get draftDeleted;

  /// Relative time: under a minute ago
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeAgoJustNow;

  /// Relative time in minutes, abbreviated
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeAgoMinutes(int minutes);

  /// Relative time in hours, abbreviated
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeAgoHours(int hours);

  /// Relative time in days, abbreviated
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeAgoDays(int days);

  /// Accessibility label of the remote-draft badge on a post card
  ///
  /// In en, this message translates to:
  /// **'Draft on GitHub'**
  String get draftOnGitHubSemantics;

  /// Badge on a post card for a Jekyll draft living on GitHub
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draftBadge;

  /// Tooltip of the post card overflow menu
  ///
  /// In en, this message translates to:
  /// **'Post actions'**
  String get postActionsTooltip;

  /// Post menu item opening the published post in the browser
  ///
  /// In en, this message translates to:
  /// **'View post'**
  String get viewPostAction;

  /// Post menu item moving a remote draft into the posts folder
  ///
  /// In en, this message translates to:
  /// **'Promote to post'**
  String get promoteToPostAction;

  /// Post menu item deleting the file from the repository
  ///
  /// In en, this message translates to:
  /// **'Delete from GitHub'**
  String get deleteFromGitHubAction;

  /// Empty-state title of the Published tab
  ///
  /// In en, this message translates to:
  /// **'No Posts Yet'**
  String get noPostsYet;

  /// Empty-state body of the Published tab
  ///
  /// In en, this message translates to:
  /// **'Your {folder} folder is empty.\nTap the button below to create your first post!'**
  String emptyPostsBody(String folder);

  /// Hint chip in the Published tab empty state
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to start writing'**
  String get tapPlusToWrite;

  /// Snackbar when leaving the editor after the draft was auto-saved
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get draftSavedSnack;

  /// Snackbar when publishing without a title
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// Generic publish success snackbar
  ///
  /// In en, this message translates to:
  /// **'Post published successfully!'**
  String get postPublishedSuccess;

  /// Snackbar after saving a new post to the remote drafts folder
  ///
  /// In en, this message translates to:
  /// **'Draft saved to GitHub: {filename}'**
  String draftSavedToGitHub(String filename);

  /// Snackbar after publishing a new post
  ///
  /// In en, this message translates to:
  /// **'Post created: {filename}'**
  String postCreated(String filename);

  /// Snackbar after updating an existing post
  ///
  /// In en, this message translates to:
  /// **'Post updated successfully!'**
  String get postUpdatedSuccess;

  /// Fallback snackbar when publishing fails without a specific message
  ///
  /// In en, this message translates to:
  /// **'Failed to publish'**
  String get failedToPublishGeneric;

  /// Snackbar after a post was added to the offline publish queue
  ///
  /// In en, this message translates to:
  /// **'Queued - will publish when back online'**
  String get queuedWillPublishWhenOnline;

  /// Title of the offline-publish dialog
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline'**
  String get offlineDialogTitle;

  /// Body of the offline-publish dialog
  ///
  /// In en, this message translates to:
  /// **'GitHub cannot be reached right now. This post can be queued and published automatically when the connection returns.'**
  String get offlineDialogBody;

  /// Offline dialog option returning to the editor
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// Offline dialog option discarding the post and its draft
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardAction;

  /// Offline dialog option adding the post to the publish queue
  ///
  /// In en, this message translates to:
  /// **'Queue and publish when online'**
  String get queueAndPublishWhenOnline;

  /// Title of the publish-conflict dialog
  ///
  /// In en, this message translates to:
  /// **'Post changed on GitHub'**
  String get conflictDialogTitle;

  /// Body of the publish-conflict dialog
  ///
  /// In en, this message translates to:
  /// **'This post was changed on GitHub after you opened it. Overwrite it with your version, or keep both to review?'**
  String get conflictDialogBody;

  /// Conflict dialog option keeping both versions
  ///
  /// In en, this message translates to:
  /// **'Keep both'**
  String get keepBoth;

  /// Conflict dialog option force-publishing the local version
  ///
  /// In en, this message translates to:
  /// **'Overwrite with my version'**
  String get overwriteWithMyVersion;

  /// Snackbar when keep-both saved the local draft but the remote file path is unknown
  ///
  /// In en, this message translates to:
  /// **'Your version was saved to drafts, but the GitHub version could not be located'**
  String get savedButRemoteNotLocated;

  /// Snackbar when keep-both saved the local draft but fetching the remote version failed
  ///
  /// In en, this message translates to:
  /// **'Your version was saved to drafts, but the GitHub version could not be loaded: {error}'**
  String savedButRemoteNotLoaded(String error);

  /// Snackbar after keep-both swapped the editor onto the remote version
  ///
  /// In en, this message translates to:
  /// **'Your version was saved to drafts - now showing the GitHub version'**
  String get savedNowShowingRemote;

  /// Snackbar when waiting for media uploads timed out
  ///
  /// In en, this message translates to:
  /// **'Uploads are taking too long - try publishing again in a moment'**
  String get uploadsTakingTooLong;

  /// Title of the pending-uploads dialog shown before publishing
  ///
  /// In en, this message translates to:
  /// **'Media still uploading'**
  String get mediaStillUploadingTitle;

  /// Body of the pending-uploads dialog
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file in this post is still uploading. Wait for it to finish?} other{{count} files in this post are still uploading. Wait for them to finish?}}'**
  String pendingUploadsBody(num count);

  /// Dialog option publishing despite pending or failed uploads
  ///
  /// In en, this message translates to:
  /// **'Publish anyway'**
  String get publishAnyway;

  /// Dialog option waiting for uploads to finish
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get waitAction;

  /// Title of the failed-uploads dialog shown before publishing
  ///
  /// In en, this message translates to:
  /// **'Media uploads failed'**
  String get mediaUploadsFailedTitle;

  /// Body of the failed-uploads dialog; the placeholder is a bulleted list of filenames
  ///
  /// In en, this message translates to:
  /// **'These files failed to upload:\n\n{files}\n\nPublishing now would leave broken media in the post.'**
  String failedUploadsBody(String files);

  /// Dialog option retrying failed media uploads
  ///
  /// In en, this message translates to:
  /// **'Retry uploads'**
  String get retryUploads;

  /// Blocking progress dialog while media uploads finish
  ///
  /// In en, this message translates to:
  /// **'Waiting for uploads...'**
  String get waitingForUploads;

  /// Image source sheet: pick from the photo gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryOption;

  /// Image source sheet: take a photo with the camera
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get cameraOption;

  /// Snackbar while an inserted image uploads in the background
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get uploadingImage;

  /// Snackbar when picking or inserting an image failed
  ///
  /// In en, this message translates to:
  /// **'Failed to add image: {error}'**
  String failedToAddImage(String error);

  /// Snackbar while a picked video is being compressed
  ///
  /// In en, this message translates to:
  /// **'Compressing video...'**
  String get compressingVideo;

  /// Snackbar while an inserted video uploads in the background
  ///
  /// In en, this message translates to:
  /// **'Uploading video...'**
  String get uploadingVideo;

  /// Editor title when editing an existing post
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get editPostTitle;

  /// Tooltip of the settings button and title of the post settings sheet
  ///
  /// In en, this message translates to:
  /// **'Post settings'**
  String get postSettingsLabel;

  /// Primary publish button in the editor
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishAction;

  /// Tooltip of the publish overflow menu
  ///
  /// In en, this message translates to:
  /// **'More publish options'**
  String get morePublishOptionsTooltip;

  /// Publish menu item saving the new post to the remote drafts folder
  ///
  /// In en, this message translates to:
  /// **'Save as draft on GitHub'**
  String get saveAsDraftOnGitHub;

  /// Editor draft status while auto-save runs
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get statusSaving;

  /// Editor draft status after a successful auto-save
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get statusSaved;

  /// Editor draft status when auto-save failed
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get statusError;

  /// Accessibility label of the editor save-status chip
  ///
  /// In en, this message translates to:
  /// **'Draft status: {status}'**
  String draftStatusSemantics(String status);

  /// Editor tab with the markdown text fields
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get tabWrite;

  /// Editor tab with the rendered markdown preview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get tabPreview;

  /// Label above the post title field
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// Hint of the post title field
  ///
  /// In en, this message translates to:
  /// **'Enter post title...'**
  String get enterPostTitleHint;

  /// Tooltip of the lock icon on the title field of an existing post
  ///
  /// In en, this message translates to:
  /// **'Title cannot be changed for existing posts'**
  String get titleLockedTooltip;

  /// Caption under the locked title field
  ///
  /// In en, this message translates to:
  /// **'Title is locked for existing posts'**
  String get titleLockedNote;

  /// Label of the editor toolbar row
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get contentLabel;

  /// Tooltip of the undo toolbar button
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoTooltip;

  /// Tooltip of the redo toolbar button
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redoTooltip;

  /// Tooltip of the keyboard-dismiss toolbar button
  ///
  /// In en, this message translates to:
  /// **'Hide keyboard'**
  String get hideKeyboardTooltip;

  /// Tooltip of the insert-image toolbar button
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get addImageTooltip;

  /// Tooltip of the insert-video toolbar button
  ///
  /// In en, this message translates to:
  /// **'Add video'**
  String get addVideoTooltip;

  /// Tooltip of the insert-YouTube-video toolbar button
  ///
  /// In en, this message translates to:
  /// **'Add YouTube video'**
  String get addYouTubeTooltip;

  /// Title of the dialog asking for a YouTube link
  ///
  /// In en, this message translates to:
  /// **'Add YouTube Video'**
  String get addYouTubeTitle;

  /// Hint of the link field in the YouTube dialog
  ///
  /// In en, this message translates to:
  /// **'Paste a YouTube link'**
  String get youTubeLinkHint;

  /// Inline error when the YouTube dialog's input is not a recognised video link
  ///
  /// In en, this message translates to:
  /// **'Not a YouTube video link'**
  String get notAYouTubeLink;

  /// Confirm button of the YouTube dialog
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get insertAction;

  /// Tooltip of the markdown reference toolbar button
  ///
  /// In en, this message translates to:
  /// **'Markdown help'**
  String get markdownHelpTooltip;

  /// Hint of the post body field
  ///
  /// In en, this message translates to:
  /// **'Start writing your post...\n\nTip: Use Markdown for formatting!'**
  String get bodyHint;

  /// Empty-state title of the Preview tab
  ///
  /// In en, this message translates to:
  /// **'Nothing to preview yet'**
  String get nothingToPreviewYet;

  /// Empty-state body of the Preview tab
  ///
  /// In en, this message translates to:
  /// **'Switch to the Write tab and add some content'**
  String get switchToWriteTab;

  /// Fallback label for an image without alt text in the preview
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get imageFallbackAlt;

  /// Fallback label for a video placeholder without a filename
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get videoFallbackLabel;

  /// Overlay on media in the preview while it uploads
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploadingEllipsis;

  /// Overlay on media in the preview when its upload failed
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadFailed;

  /// Accessibility label of the retry button on a failed media upload
  ///
  /// In en, this message translates to:
  /// **'Retry upload of {filename}'**
  String retryUploadOf(String filename);

  /// Title of the markdown help sheet
  ///
  /// In en, this message translates to:
  /// **'Markdown Quick Reference'**
  String get markdownQuickReference;

  /// Markdown help: description of # syntax
  ///
  /// In en, this message translates to:
  /// **'Large heading'**
  String get mdLargeHeading;

  /// Markdown help: description of ## syntax
  ///
  /// In en, this message translates to:
  /// **'Medium heading'**
  String get mdMediumHeading;

  /// Markdown help: description of ** syntax
  ///
  /// In en, this message translates to:
  /// **'Bold text'**
  String get mdBoldText;

  /// Markdown help: description of * syntax
  ///
  /// In en, this message translates to:
  /// **'Italic text'**
  String get mdItalicText;

  /// Markdown help: description of link syntax
  ///
  /// In en, this message translates to:
  /// **'Hyperlink'**
  String get mdHyperlink;

  /// Markdown help: description of image syntax
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get mdImage;

  /// Markdown help: description of - syntax
  ///
  /// In en, this message translates to:
  /// **'Bullet list'**
  String get mdBulletList;

  /// Markdown help: description of 1. syntax
  ///
  /// In en, this message translates to:
  /// **'Numbered list'**
  String get mdNumberedList;

  /// Markdown help: description of > syntax
  ///
  /// In en, this message translates to:
  /// **'Block quote'**
  String get mdBlockQuote;

  /// Markdown help: description of backtick syntax
  ///
  /// In en, this message translates to:
  /// **'Inline code'**
  String get mdInlineCode;

  /// Label of the publication date row in post settings
  ///
  /// In en, this message translates to:
  /// **'Publication date'**
  String get publicationDateLabel;

  /// Caption under the date row when showing an existing post's date
  ///
  /// In en, this message translates to:
  /// **'Current post date - tap to change'**
  String get currentPostDateHint;

  /// Caption under the date row for a new post
  ///
  /// In en, this message translates to:
  /// **'Set automatically when you publish - tap to override'**
  String get dateSetAutomaticallyHint;

  /// Hint of the layout field in post settings
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the site default'**
  String get layoutEmptyHint;

  /// Label of the categories chip editor
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesLabel;

  /// Hint of the category input field
  ///
  /// In en, this message translates to:
  /// **'Add a category...'**
  String get addCategoryHint;

  /// Label of the tags chip editor
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsLabel;

  /// Hint of the tag input field
  ///
  /// In en, this message translates to:
  /// **'Add a tag...'**
  String get addTagHint;

  /// Label of the read-only custom front matter preview
  ///
  /// In en, this message translates to:
  /// **'Custom fields'**
  String get customFieldsLabel;

  /// Caption under the custom front matter preview
  ///
  /// In en, this message translates to:
  /// **'These fields are preserved as-is when you publish'**
  String get customFieldsPreservedNote;

  /// App display name on the About screen. Do not translate.
  ///
  /// In en, this message translates to:
  /// **'Jekyll Press'**
  String get aboutAppName;

  /// Version badge while the package info loads
  ///
  /// In en, this message translates to:
  /// **'Version …'**
  String get versionLoading;

  /// Version badge on the About screen
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String versionLabel(String version, String build);

  /// About screen: intro section title
  ///
  /// In en, this message translates to:
  /// **'About Jekyll Press'**
  String get aboutSectionTitle;

  /// About screen: intro section body
  ///
  /// In en, this message translates to:
  /// **'Jekyll Press is a mobile-first CMS for any Jekyll blog hosted on GitHub. Write, edit, and publish posts directly from your phone — no laptop, no git commands.\n\nBuilt with Flutter and powered by the GitHub REST API, it works with your repository as-is: your posts folder, drafts, collections, branch, and front matter conventions are all configurable.'**
  String get aboutSectionBody;

  /// About screen: motivation section title
  ///
  /// In en, this message translates to:
  /// **'Motivation'**
  String get motivationTitle;

  /// About screen: motivation section body
  ///
  /// In en, this message translates to:
  /// **'As a developer who blogs on GitHub Pages, I often found inspiration for new posts while away from my computer. Jekyll Press was born from the need to capture and publish those ideas immediately, without waiting to get back to a desktop.\n\nThe goal is simple: make mobile blogging on Jekyll as seamless as writing in any native notes app.'**
  String get motivationBody;

  /// About screen: usage section title
  ///
  /// In en, this message translates to:
  /// **'How to Use'**
  String get howToUseTitle;

  /// About screen: usage section body
  ///
  /// In en, this message translates to:
  /// **'1. Tap \"Sign in with GitHub\" and approve the code on github.com — or paste a Personal Access Token instead\n2. Select your Jekyll blog repository and branch\n3. Confirm the detected posts, drafts, and assets folders\n4. Start writing! Tap the + button to create a new post\n5. Add photos and videos straight from your gallery or camera\n6. Use the Preview tab to see your formatted markdown\n7. Hit Publish to push directly to GitHub — or queue it while offline'**
  String get howToUseBody;

  /// About screen: limitations section title
  ///
  /// In en, this message translates to:
  /// **'Limitations'**
  String get limitationsTitle;

  /// About screen: limitations section body, including what the GitHub sign-in grants and how to revoke it
  ///
  /// In en, this message translates to:
  /// **'• Android only\n• \"Sign in with GitHub\" asks for the repo scope: read and write access to your repositories, public and private. It is the narrowest scope that lets an OAuth app edit files in a private repo. JekyllPress only touches the repository you configure, and you can revoke access any time at github.com → Settings → Applications → Authorized OAuth Apps. For access to a single repository, sign in with a fine-grained Personal Access Token instead\n• Published posts cannot be renamed in-app (the filename dictates the permalink; renames would break links)\n• Videos are re-encoded with the short edge capped at 640px, and uploads are capped at 25MB\n• Repository files are edited one at a time via the GitHub API (no multi-file commits or merges)'**
  String get limitationsBody;

  /// About screen: privacy section title
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacySectionTitle;

  /// About screen: privacy section body
  ///
  /// In en, this message translates to:
  /// **'Everything stays between your device and your own GitHub repository. Your token lives in Android\'s encrypted, Keystore-backed storage; there are no analytics and no third-party servers. Logging out deletes the token from this device and wipes all cached content — it does not revoke the token on GitHub, so revoke it there too if you want the authorization gone.'**
  String get privacySectionBody;

  /// Button opening the privacy policy on GitHub
  ///
  /// In en, this message translates to:
  /// **'Read the privacy policy'**
  String get readPrivacyPolicy;

  /// About screen: open source section title
  ///
  /// In en, this message translates to:
  /// **'Open Source'**
  String get openSourceTitle;

  /// About screen: open source section body
  ///
  /// In en, this message translates to:
  /// **'Jekyll Press is open source under the MIT License. Found a bug or have a feature request? Head over to GitHub to:\n\n• Report issues\n• Request features\n• Contribute code\n• Star the repo ⭐'**
  String get openSourceBody;

  /// Button opening the project repository
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get viewOnGitHub;

  /// Caption above the creator's name on the About screen
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get createdByLabel;

  /// Accessibility label of the creator card. The URL should not be translated.
  ///
  /// In en, this message translates to:
  /// **'Open the creator\'s website, www.gapp.in'**
  String get creatorCardSemantics;

  /// About screen: license section title. Proper name of the license; usually not translated.
  ///
  /// In en, this message translates to:
  /// **'MIT License'**
  String get mitLicenseTitle;

  /// Snackbar when a link was copied because no browser could open it
  ///
  /// In en, this message translates to:
  /// **'Link copied: {url}'**
  String linkCopiedSnack(String url);

  /// Reminder in the fallback setup card that the GitHub App must also be installed on the blog repo
  ///
  /// In en, this message translates to:
  /// **'Last step: on your new app\'s page, open \"Install App\" and give it access to your blog repository.'**
  String get oneTimeSetupInstallHint;

  /// Hint in the fallback setup card about GitHub App name uniqueness
  ///
  /// In en, this message translates to:
  /// **'If GitHub says the name is taken, add something to make it unique.'**
  String get appNameTakenHint;

  /// Escape hatch on the device-flow error state, reopens the setup card. Only shown in builds with no bundled Client ID
  ///
  /// In en, this message translates to:
  /// **'Change Client ID'**
  String get changeClientId;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
