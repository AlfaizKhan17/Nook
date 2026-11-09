import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../models/social_post.dart';
import '../services/item_service.dart';
import '../services/social_post_service.dart';
import '../widgets/item_card.dart';
import 'item_details_screen.dart';
import 'post_comments_screen.dart';

class MyPostsScreen extends StatefulWidget {
  final bool embedded;

  const MyPostsScreen({super.key, this.embedded = false});

  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final ItemService _itemsService = ItemService();
  final SocialPostService _socialService = SocialPostService();

  List<ItemModel> _items = [];
  List<SocialPost> _socialPosts = [];
  bool _loading = true;
  bool _showCommunity = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _itemsService.getMyPosts(),
        _socialService.getMySocialPosts(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<ItemModel>;
        _socialPosts = results[1] as List<SocialPost>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load your posts: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSocialPost(SocialPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This also deletes its comments and likes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _socialService.deletePost(post.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete post: $e')),
        );
      }
    }
  }

  Future<void> _toggleLike(SocialPost post) async {
    try {
      await _socialService.toggleLike(post);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update like: $e')),
        );
      }
    }
  }

  Widget _communityCard(ThemeData theme, SocialPost post) {
    final name = post.authorName?.trim().isNotEmpty == true
        ? post.authorName!
        : 'You';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(name[0].toUpperCase(), style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: theme.textTheme.titleSmall),
              Text(post.createdAt.toLocal().toString().split('.').first, style: theme.textTheme.bodySmall),
            ])),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _deleteSocialPost(post);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete post')),
              ],
            ),
          ]),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(post.content, style: theme.textTheme.bodyLarge),
          ],
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _postImages(theme, post.imageUrls),
          ],
          const SizedBox(height: 8),
          Divider(color: theme.dividerColor),
          Row(children: [
            TextButton.icon(
              onPressed: () => _toggleLike(post),
              icon: Icon(
                post.likedByMe ? Icons.favorite : Icons.favorite_border,
                color: post.likedByMe ? theme.colorScheme.error : null,
              ),
              label: Text('${post.likeCount}'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PostCommentsScreen(postId: post.id)),
              ).then((_) => _load()),
              icon: const Icon(Icons.mode_comment_outlined),
              label: Text('${post.commentCount}'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _postImages(ThemeData theme, List<String> urls) {
    if (urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          urls.first,
          width: double.infinity,
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageError(theme),
        ),
      );
    }
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) => ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Image.network(
            urls[index],
            width: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imageError(theme),
          ),
        ),
      ),
    );
  }

  Widget _imageError(ThemeData theme) => Container(
        width: 180,
        height: 180,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image_outlined),
      );

  Widget _content(ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_showCommunity) {
      if (_socialPosts.isEmpty) return _empty(theme, 'No community posts yet.');
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
          itemCount: _socialPosts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => _communityCard(theme, _socialPosts[index]),
        ),
      );
    }

    if (_items.isEmpty) return _empty(theme, 'No Lost & Found listings yet.');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) => ItemCard(
          item: _items[index],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: _items[index])),
          ).then((_) => _load()),
        ),
      ),
    );
  }

  Widget _empty(ThemeData theme, String message) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 145),
          Icon(Icons.inbox_outlined, size: 54, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Center(child: Text(message, style: theme.textTheme.titleMedium)),
          const SizedBox(height: 5),
          Center(child: Text('Your activity will appear here.', style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Text('My Posts', style: theme.textTheme.displayLarge?.copyWith(fontSize: 30)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Lost & Found')),
            ButtonSegment(value: true, label: Text('Community')),
          ],
          selected: {_showCommunity},
          onSelectionChanged: (selection) => setState(() => _showCommunity = selection.first),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(child: _content(theme)),
    ]);

    if (widget.embedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('My Posts')),
      body: body,
    );
  }
}
