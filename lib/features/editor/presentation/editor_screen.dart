import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/blog_post.dart';
import '../../../core/providers/editor_provider.dart';
import '../../../core/providers/image_provider.dart';
import '../../../core/providers/posts_provider.dart';
import '../../../core/providers/publish_provider.dart';
import '../../../core/theme/app_theme.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final BlogPost? post;

  const EditorScreen({super.key, this.post});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  final FocusNode _bodyFocusNode = FocusNode();

  bool get isNewPost => widget.post == null;
  bool _isInitialized = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleController = TextEditingController();
    _bodyController = TextEditingController();

    _tabController.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      
      // Set up text controller values immediately (no provider modification)
      if (widget.post != null) {
        _titleController.text = widget.post!.title;
        _bodyController.text = widget.post!.bodyContent;
      }
      
      // Add listeners
      _titleController.addListener(_onTitleChanged);
      _bodyController.addListener(_onBodyChanged);
      
      // Delay provider modification until after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeEditorProvider();
      });
    }
  }

  void _initializeEditorProvider() {
    if (!mounted) return;
    
    final controller = ref.read(editorControllerProvider.notifier);

    if (widget.post != null) {
      controller.initializeWithPost(widget.post!);
    } else {
      controller.initializeNewPost();
    }
  }

  void _onTitleChanged() {
    ref.read(editorControllerProvider.notifier).updateTitle(_titleController.text);
  }

  void _onBodyChanged() {
    ref.read(editorControllerProvider.notifier).updateBody(_bodyController.text);
  }

  void _onTabChanged() {
    // Unfocus text fields when switching to preview
    if (_tabController.index == 1) {
      FocusScope.of(context).unfocus();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _titleController.removeListener(_onTitleChanged);
    _bodyController.removeListener(_onBodyChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    final editorState = ref.read(editorControllerProvider);
    if (editorState.hasUnsavedChanges) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A2F23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Discard Changes?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to leave?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE57373),
              ),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      return shouldDiscard ?? false;
    }
    return true;
  }

  void _handleBack() async {
    if (await _onWillPop()) {
      ref.read(editorControllerProvider.notifier).clear();
      if (mounted) Navigator.of(context).pop();
    }
  }

  bool _isPublishing = false;

  Future<void> _handleSave() async {
    final editorState = ref.read(editorControllerProvider);

    if (editorState.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    HapticFeedback.mediumImpact();

    try {
      final publishNotifier = ref.read(publishNotifierProvider.notifier);
      bool success;

      if (isNewPost) {
        // Create new post
        success = await publishNotifier.publishNewPost(
          title: editorState.title,
          bodyContent: editorState.bodyContent,
        );
      } else {
        // Update existing post
        success = await publishNotifier.publishUpdate(
          originalPost: widget.post!,
          newBodyContent: editorState.bodyContent,
        );
      }

      if (success && mounted) {
        // Clear editor state
        ref.read(editorControllerProvider.notifier).clear();
        
        // Refresh posts list
        ref.read(postsNotifierProvider.notifier).refresh();

        // Show success message
        final publishState = ref.read(publishNotifierProvider);
        String message = 'Post published successfully!';
        if (publishState is PublishSucceeded) {
          message = isNewPost 
              ? 'Post created: ${publishState.filename}'
              : 'Post updated successfully!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF81C784), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1A2F23),
          ),
        );

        // Reset publish state and navigate back
        publishNotifier.reset();
        Navigator.of(context).pop();
      } else if (mounted) {
        // Show error
        final publishState = ref.read(publishNotifierProvider);
        String error = 'Failed to publish';
        if (publishState is PublishFailed) {
          error = publishState.error;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFE57373), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(error)),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1A2F23),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  Future<void> _handleAddImage() async {
    if (_isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      final imageManager = ref.read(imageManagerProvider.notifier);
      final filename = await imageManager.pickImage();

      if (filename != null && mounted) {
        // Generate markdown and insert at cursor
        final markdown = imageManager.generateMarkdownImage(filename);
        _insertTextAtCursor('\n$markdown\n');

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE8A87C),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Uploading image...'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add image: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFE57373),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _insertTextAtCursor(String text) {
    final currentText = _bodyController.text;
    final selection = _bodyController.selection;

    int insertPosition;
    if (selection.isValid && selection.baseOffset >= 0) {
      insertPosition = selection.baseOffset;
    } else {
      insertPosition = currentText.length;
    }

    final newText = currentText.substring(0, insertPosition) +
        text +
        currentText.substring(insertPosition);

    _bodyController.text = newText;
    _bodyController.selection = TextSelection.collapsed(
      offset: insertPosition + text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: Container(
          decoration: AppTheme.backgroundGradient,
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(editorState),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildWriteTab(editorState),
                      _buildPreviewTab(editorState),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(EditorState editorState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFFA8B5A0),
            onPressed: _handleBack,
          ),
          Expanded(
            child: Text(
              isNewPost ? 'New Post' : 'Edit Post',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (editorState.hasUnsavedChanges)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8A87C).withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: Color(0xFFE8A87C),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Unsaved',
                    style: TextStyle(
                      color: Color(0xFFE8A87C),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ElevatedButton(
            onPressed: _isPublishing ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: _isPublishing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0D1B14),
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.publish_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Publish'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF162A1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D4A3E).withAlpha(80),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFFE8A87C),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF0D1B14),
        unselectedLabelColor: const Color(0xFFA8B5A0),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_rounded, size: 18),
                SizedBox(width: 8),
                Text('Write'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_rounded, size: 18),
                SizedBox(width: 8),
                Text('Preview'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteTab(EditorState editorState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title field
          Text(
            'Title',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: AppTheme.cardGlow,
            child: TextField(
              controller: _titleController,
              enabled: isNewPost,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isNewPost
                    ? const Color(0xFFF5F5F0)
                    : const Color(0xFFA8B5A0),
              ),
              decoration: InputDecoration(
                hintText: 'Enter post title...',
                filled: true,
                fillColor: isNewPost
                    ? const Color(0xFF162A1E)
                    : const Color(0xFF162A1E).withAlpha(150),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF2D4A3E).withAlpha(80),
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF2D4A3E).withAlpha(40),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFE8A87C),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                suffixIcon: !isNewPost
                    ? Tooltip(
                        message: 'Title cannot be changed for existing posts',
                        child: Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: const Color(0xFFA8B5A0).withAlpha(150),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          if (!isNewPost) ...[
            const SizedBox(height: 6),
            Text(
              'Title is locked for existing posts',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFA8B5A0).withAlpha(150),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Toolbar row
          _buildToolbar(),
          const SizedBox(height: 8),

          // Body field
          Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            decoration: AppTheme.cardGlow,
            child: TextField(
              controller: _bodyController,
              focusNode: _bodyFocusNode,
              maxLines: null,
              minLines: 15,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                fontFamily: 'monospace',
                color: Color(0xFFF5F5F0),
              ),
              decoration: InputDecoration(
                hintText: 'Start writing your post...\n\nTip: Use Markdown for formatting!',
                hintStyle: TextStyle(
                  color: const Color(0xFFA8B5A0).withAlpha(150),
                  fontFamily: 'monospace',
                ),
                filled: true,
                fillColor: const Color(0xFF162A1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF2D4A3E).withAlpha(80),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFE8A87C),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF162A1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D4A3E).withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Content',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const Spacer(),
          // Add Image button
          _ToolbarButton(
            icon: Icons.image_rounded,
            label: 'Image',
            onPressed: _isPickingImage ? null : _handleAddImage,
            isLoading: _isPickingImage,
          ),
          const SizedBox(width: 8),
          // Markdown help button
          _ToolbarButton(
            icon: Icons.help_outline_rounded,
            label: 'Help',
            onPressed: _showMarkdownHelp,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab(EditorState editorState) {
    final hasContent = editorState.bodyContent.trim().isNotEmpty;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: const Color(0xFFA8B5A0).withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing to preview yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFA8B5A0),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Switch to the Write tab and add some content',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title preview
          if (editorState.title.isNotEmpty) ...[
            Text(
              editorState.title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF5F5F0),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(DateTime.now()),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFA8B5A0),
              ),
            ),
            const Divider(
              height: 32,
              color: Color(0xFF2D4A3E),
            ),
          ],

          // Markdown content with smart image resolver
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF162A1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2D4A3E).withAlpha(80),
              ),
            ),
            child: MarkdownBody(
              data: editorState.bodyContent,
              selectable: true,
              styleSheet: _buildMarkdownStyleSheet(),
              sizedImageBuilder: (config) => _buildImage(config.uri, config.title, config.alt),
            ),
          ),
        ],
      ),
    );
  }

  /// Smart image resolver - checks local cache first, falls back to GitHub
  Widget _buildImage(Uri uri, String? title, String? alt) {
    final imageResolver = ref.read(imageResolverProvider.notifier);
    final imageManager = ref.read(imageManagerProvider.notifier);
    
    final path = uri.toString();
    final (isLocal, resolvedPath) = imageResolver.resolveImagePath(path);
    
    // Get upload status for this image
    final filename = path.split('/').last;
    final uploadStatus = imageManager.getStatus(filename);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isLocal
                ? Image.file(
                    File(resolvedPath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImageError(alt ?? 'Image'),
                  )
                : Image.network(
                    resolvedPath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildImageLoading();
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImageError(alt ?? 'Image'),
                  ),
          ),
          // Upload status overlay
          if (uploadStatus != null && uploadStatus.isUploading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE8A87C),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Uploading...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Upload error overlay
          if (uploadStatus != null && uploadStatus.error != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFE57373),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Upload failed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => imageManager.retryUpload(filename),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageLoading() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF2D4A3E).withAlpha(50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE8A87C),
        ),
      ),
    );
  }

  Widget _buildImageError(String alt) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF2D4A3E).withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE57373).withAlpha(50),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_rounded,
              color: Color(0xFFA8B5A0),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              alt,
              style: const TextStyle(
                color: Color(0xFFA8B5A0),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      p: const TextStyle(
        fontSize: 15,
        height: 1.7,
        color: Color(0xFFF5F5F0),
      ),
      h1: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: Color(0xFFF5F5F0),
        height: 1.4,
      ),
      h2: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF5F5F0),
        height: 1.4,
      ),
      h3: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF5F5F0),
        height: 1.4,
      ),
      h4: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF5F5F0),
        height: 1.4,
      ),
      h5: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFFF5F5F0),
        height: 1.4,
      ),
      h6: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFFA8B5A0),
        height: 1.4,
      ),
      em: const TextStyle(
        fontStyle: FontStyle.italic,
        color: Color(0xFFF5F5F0),
      ),
      strong: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFFF5F5F0),
      ),
      blockquote: const TextStyle(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        color: Color(0xFFA8B5A0),
        height: 1.6,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFFE8A87C).withAlpha(150),
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: const Color(0xFFE8A87C),
        backgroundColor: const Color(0xFF2D4A3E).withAlpha(100),
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFF0D1B14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2D4A3E).withAlpha(100),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      listBullet: const TextStyle(
        color: Color(0xFFE8A87C),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFF2D4A3E).withAlpha(150),
            width: 1,
          ),
        ),
      ),
      a: const TextStyle(
        color: Color(0xFFE8A87C),
        decoration: TextDecoration.underline,
      ),
    );
  }

  void _showMarkdownHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2F23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFFE8A87C),
                ),
                const SizedBox(width: 12),
                Text(
                  'Markdown Quick Reference',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildMarkdownHelpRow('# Heading 1', 'Large heading'),
            _buildMarkdownHelpRow('## Heading 2', 'Medium heading'),
            _buildMarkdownHelpRow('**bold**', 'Bold text'),
            _buildMarkdownHelpRow('*italic*', 'Italic text'),
            _buildMarkdownHelpRow('[link](url)', 'Hyperlink'),
            _buildMarkdownHelpRow('![alt](url)', 'Image'),
            _buildMarkdownHelpRow('- item', 'Bullet list'),
            _buildMarkdownHelpRow('1. item', 'Numbered list'),
            _buildMarkdownHelpRow('> quote', 'Block quote'),
            _buildMarkdownHelpRow('`code`', 'Inline code'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownHelpRow(String syntax, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              syntax,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Color(0xFFE8A87C),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFA8B5A0),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Toolbar button widget
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2D4A3E).withAlpha(60),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE8A87C),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 16,
                  color: const Color(0xFFE8A87C),
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFA8B5A0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
