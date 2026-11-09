import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/social_post_service.dart';

class PostCommentsScreen extends StatefulWidget {
  final String postId;

  const PostCommentsScreen({super.key, required this.postId});

  @override
  State<PostCommentsScreen> createState() => _PostCommentsScreenState();
}

class _PostCommentsScreenState extends State<PostCommentsScreen> {
  final SocialPostService _service = SocialPostService();
  final TextEditingController _controller = TextEditingController();

  List<Map<String, dynamic>> _comments = [];
  String? _replyToId;
  String? _replyToName;
  bool _loading = true;
  bool _sending = false;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _load() async {
    try {
      final data = await _service.getComments(widget.postId);
      if (mounted) setState(() => _comments = data);
    } catch (e) {
      _message('Could not load comments: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _childrenByParent() {
    final ids = _comments.map((c) => c['id'].toString()).toSet();
    final result = <String, List<Map<String, dynamic>>>{'root': []};

    for (final comment in _comments) {
      final parent = comment['parent_comment_id']?.toString();
      final key = parent != null && ids.contains(parent) ? parent : 'root';
      (result[key] ??= []).add(comment);
    }
    return result;
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await _service.addComment(
        widget.postId,
        content,
        parentCommentId: _replyToId,
      );
      _controller.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _replyToId = null;
        _replyToName = null;
      });
      await _load();
    } catch (e) {
      _message('Could not send comment: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _reply(Map<String, dynamic> comment) {
    final profile = comment['profiles'];
    final name = profile is Map ? (profile['name'] ?? 'Student').toString() : 'Student';
    setState(() {
      _replyToId = comment['id'].toString();
      _replyToName = name;
    });
  }

  Future<void> _delete(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This will also remove replies to this comment.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteComment(comment['id'].toString());
      await _load();
    } catch (e) {
      _message('Could not delete comment: $e');
    }
  }

  Widget _commentTile(
    ThemeData theme,
    Map<String, dynamic> comment,
    Map<String, List<Map<String, dynamic>>> children, {
    int depth = 0,
  }) {
    final profile = comment['profiles'];
    final name = profile is Map ? (profile['name'] ?? 'Student').toString() : 'Student';
    final isMine = comment['user_id']?.toString() == _userId;
    final replies = children[comment['id'].toString()] ?? const [];

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 22, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                name.isEmpty ? 'S' : name[0].toUpperCase(),
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 5),
                  Text(comment['content']?.toString() ?? '', style: theme.textTheme.bodyLarge?.copyWith(height: 1.4)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 12, children: [
                    TextButton(
                      onPressed: () => _reply(comment),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                      child: const Text('Reply'),
                    ),
                    if (isMine)
                      TextButton(
                        onPressed: () => _delete(comment),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Delete'),
                      ),
                  ]),
                ]),
              ),
            ),
          ]),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: replies.map((reply) => _commentTile(
                  theme,
                  reply,
                  children,
                  depth: depth + 1,
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = _childrenByParent();

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _comments.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 150),
                              Icon(Icons.chat_bubble_outline, size: 48, color: theme.colorScheme.primary),
                              const SizedBox(height: 12),
                              Center(child: Text('Start the conversation', style: theme.textTheme.titleMedium)),
                              const SizedBox(height: 5),
                              Center(child: Text('Be the first to comment.', style: theme.textTheme.bodyMedium)),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                            children: (children['root'] ?? const [])
                                .map((comment) => _commentTile(theme, comment, children))
                                .toList(),
                          ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_replyToId != null)
                  Row(children: [
                    Expanded(child: Text('Replying to $_replyToName', style: theme.textTheme.bodySmall)),
                    IconButton(
                      tooltip: 'Cancel reply',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        _replyToId = null;
                        _replyToName = null;
                      }),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ]),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _replyToId == null ? 'Write a comment...' : 'Write a reply...',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
