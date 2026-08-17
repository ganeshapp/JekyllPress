import 'package:hive/hive.dart';

part 'app_config.g.dart';

/// App configuration (Hive typeId 0).
///
/// MIGRATION SAFETY: every field added after v1 (indexes 4+) is stored as
/// a NULLABLE @HiveField with a non-nullable getter that supplies the
/// default, so records written by v1.x deserialize cleanly. Prefer the
/// getters ([postsPath], [draftsPath], ...) over the raw fields.
@HiveType(typeId: 0)
class AppConfig extends HiveObject {
  @HiveField(0)
  String repoOwner;

  @HiveField(1)
  String repoName;

  @HiveField(2)
  String branch;

  @HiveField(3)
  String assetsPath;

  /// Stored value for [postsPath]; null in v1 records
  @HiveField(4)
  String? postsPathRaw;

  /// Stored value for [draftsPath]; null in v1 records
  @HiveField(5)
  String? draftsPathRaw;

  /// Stored value for [siteUrl]; null in v1 records
  @HiveField(6)
  String? siteUrlRaw;

  /// Stored value for [baseurl]; null in v1 records
  @HiveField(7)
  String? baseurlRaw;

  /// Front-matter layout to inject on new posts; null = omit (the site's
  /// _config.yml defaults supply the layout)
  @HiveField(8)
  String? defaultLayout;

  /// Stored value for [defaultCategories]; null in v1 records
  @HiveField(9)
  List<String>? defaultCategoriesRaw;

  /// Stored value for [defaultTags]; null in v1 records
  @HiveField(10)
  List<String>? defaultTagsRaw;

  /// Stored value for [contentDirs]; null in v1 records
  @HiveField(11)
  List<String>? contentDirsRaw;

  /// Stored value for [activeContentDir]; null in v1 records
  @HiveField(12)
  String? activeContentDirRaw;

  /// Directory Jekyll posts live in ('' is treated as unset)
  String get postsPath =>
      (postsPathRaw?.isNotEmpty ?? false) ? postsPathRaw! : '_posts';

  /// Directory Jekyll drafts live in ('' is treated as unset)
  String get draftsPath =>
      (draftsPathRaw?.isNotEmpty ?? false) ? draftsPathRaw! : '_drafts';

  /// Public site URL, e.g. https://example.com ('' = not set)
  String get siteUrl => siteUrlRaw ?? '';

  /// GitHub Pages project-site prefix, e.g. /repo ('' = root site)
  String get baseurl => baseurlRaw ?? '';

  /// Front-matter categories to inject on new posts; empty = omit
  List<String> get defaultCategories => defaultCategoriesRaw ?? const [];

  /// Front-matter tags to inject on new posts; empty = omit
  List<String> get defaultTags => defaultTagsRaw ?? const [];

  /// Jekyll content dirs the app can publish to (posts + collections
  /// like _wiki); defaults to just [postsPath]
  List<String> get contentDirs =>
      (contentDirsRaw?.isNotEmpty ?? false) ? contentDirsRaw! : [postsPath];

  /// The content dir the app currently syncs from / publishes to
  /// ('' is treated as unset)
  String get activeContentDir =>
      (activeContentDirRaw?.isNotEmpty ?? false)
          ? activeContentDirRaw!
          : postsPath;

  AppConfig({
    required this.repoOwner,
    required this.repoName,
    this.branch = 'main',
    this.assetsPath = 'assets/images',
    String? postsPath,
    String? draftsPath,
    String? siteUrl,
    String? baseurl,
    this.defaultLayout,
    List<String>? defaultCategories,
    List<String>? defaultTags,
    List<String>? contentDirs,
    String? activeContentDir,
  })  : postsPathRaw = postsPath,
        draftsPathRaw = draftsPath,
        siteUrlRaw = siteUrl,
        baseurlRaw = baseurl,
        defaultCategoriesRaw = defaultCategories,
        defaultTagsRaw = defaultTags,
        contentDirsRaw = contentDirs,
        activeContentDirRaw = activeContentDir;

  AppConfig copyWith({
    String? repoOwner,
    String? repoName,
    String? branch,
    String? assetsPath,
    String? postsPath,
    String? draftsPath,
    String? siteUrl,
    String? baseurl,
    String? defaultLayout,
    List<String>? defaultCategories,
    List<String>? defaultTags,
    List<String>? contentDirs,
    String? activeContentDir,
  }) {
    return AppConfig(
      repoOwner: repoOwner ?? this.repoOwner,
      repoName: repoName ?? this.repoName,
      branch: branch ?? this.branch,
      assetsPath: assetsPath ?? this.assetsPath,
      postsPath: postsPath ?? postsPathRaw,
      draftsPath: draftsPath ?? draftsPathRaw,
      siteUrl: siteUrl ?? siteUrlRaw,
      baseurl: baseurl ?? baseurlRaw,
      defaultLayout: defaultLayout ?? this.defaultLayout,
      defaultCategories: defaultCategories ?? defaultCategoriesRaw,
      defaultTags: defaultTags ?? defaultTagsRaw,
      contentDirs: contentDirs ?? contentDirsRaw,
      activeContentDir: activeContentDir ?? activeContentDirRaw,
    );
  }
}
