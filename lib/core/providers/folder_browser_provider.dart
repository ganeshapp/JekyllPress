import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'auth_provider.dart';

part 'folder_browser_provider.g.dart';

/// Represents a folder entry from GitHub contents API
class RepoFolder {
  final String name;
  final String path;
  final String type;

  const RepoFolder({
    required this.name,
    required this.path,
    required this.type,
  });

  factory RepoFolder.fromJson(Map<String, dynamic> json) {
    return RepoFolder(
      name: json['name'] as String,
      path: json['path'] as String,
      type: json['type'] as String,
    );
  }

  bool get isDirectory => type == 'dir';
}

/// State for the folder browser
class FolderBrowserState {
  final String currentPath;
  final List<RepoFolder> folders;
  final bool isLoading;
  final String? error;

  const FolderBrowserState({
    this.currentPath = '',
    this.folders = const [],
    this.isLoading = false,
    this.error,
  });

  FolderBrowserState copyWith({
    String? currentPath,
    List<RepoFolder>? folders,
    bool? isLoading,
    String? error,
  }) {
    return FolderBrowserState(
      currentPath: currentPath ?? this.currentPath,
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Get parent path (for navigation up)
  String get parentPath {
    if (currentPath.isEmpty) return '';
    final parts = currentPath.split('/');
    if (parts.length <= 1) return '';
    return parts.sublist(0, parts.length - 1).join('/');
  }

  /// Check if at root level
  bool get isAtRoot => currentPath.isEmpty;

  /// Get display name for current folder
  String get currentFolderName {
    if (currentPath.isEmpty) return 'Repository Root';
    return currentPath.split('/').last;
  }
}

/// Manages folder browsing state for a GitHub repository
@riverpod
class FolderBrowserNotifier extends _$FolderBrowserNotifier {
  late String _repoOwner;
  late String _repoName;
  late Dio _dio;

  @override
  FolderBrowserState build() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://api.github.com',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ));
    return const FolderBrowserState();
  }

  /// Initialize the browser with repo details and load root folders
  Future<void> initialize({
    required String repoOwner,
    required String repoName,
  }) async {
    _repoOwner = repoOwner;
    _repoName = repoName;
    await _loadFolders('');
  }

  /// Navigate into a folder
  Future<void> navigateToFolder(String path) async {
    await _loadFolders(path);
  }

  /// Navigate up to parent folder
  Future<void> navigateUp() async {
    if (state.isAtRoot) return;
    await _loadFolders(state.parentPath);
  }

  /// Refresh current folder
  Future<void> refresh() async {
    await _loadFolders(state.currentPath);
  }

  /// Load folders at the given path
  Future<void> _loadFolders(String path) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final secureStorage = ref.read(secureStorageProvider);
      final token = await secureStorage.getToken();
      if (token == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Not authenticated',
        );
        return;
      }

      final endpoint = path.isEmpty
          ? '/repos/$_repoOwner/$_repoName/contents'
          : '/repos/$_repoOwner/$_repoName/contents/$path';

      final response = await _dio.get(
        endpoint,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> items = response.data;
        final folders = items
            .map((item) => RepoFolder.fromJson(item))
            .where((item) => item.isDirectory)
            .toList();

        // Sort folders alphabetically
        folders.sort((a, b) => a.name.compareTo(b.name));

        state = FolderBrowserState(
          currentPath: path,
          folders: folders,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load folders',
        );
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to load folders';
      if (e.response?.statusCode == 404) {
        // Empty directory or doesn't exist - treat as empty
        state = FolderBrowserState(
          currentPath: path,
          folders: const [],
          isLoading: false,
        );
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error: $e',
      );
    }
  }
}
