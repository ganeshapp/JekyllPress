import 'package:hive/hive.dart';

part 'app_config.g.dart';

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

  AppConfig({
    required this.repoOwner,
    required this.repoName,
    this.branch = 'main',
    this.assetsPath = 'assets/images',
  });

  AppConfig copyWith({
    String? repoOwner,
    String? repoName,
    String? branch,
    String? assetsPath,
  }) {
    return AppConfig(
      repoOwner: repoOwner ?? this.repoOwner,
      repoName: repoName ?? this.repoName,
      branch: branch ?? this.branch,
      assetsPath: assetsPath ?? this.assetsPath,
    );
  }
}
