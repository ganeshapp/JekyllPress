/// Represents a GitHub repository
class GitHubRepo {
  final int id;
  final String name;
  final String fullName;
  final String ownerLogin;
  final String? description;
  final bool isPrivate;
  final String defaultBranch;
  final String htmlUrl;

  const GitHubRepo({
    required this.id,
    required this.name,
    required this.fullName,
    required this.ownerLogin,
    this.description,
    required this.isPrivate,
    required this.defaultBranch,
    required this.htmlUrl,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) {
    return GitHubRepo(
      id: json['id'] as int,
      name: json['name'] as String,
      fullName: json['full_name'] as String,
      ownerLogin: json['owner']['login'] as String,
      description: json['description'] as String?,
      isPrivate: json['private'] as bool,
      defaultBranch: json['default_branch'] as String,
      htmlUrl: json['html_url'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitHubRepo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
