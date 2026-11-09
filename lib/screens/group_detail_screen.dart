import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/campus_group.dart';
import '../models/join_request.dart';
import '../models/social_post.dart';
import '../services/group_service.dart';
import '../services/social_post_service.dart';
import '../widgets/join_request_tile.dart';
import 'post_comments_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final CampusGroup group;

  const GroupDetailScreen({
    super.key,
    required this.group,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;
  final SocialPostService _posts = SocialPostService();
  final GroupService _groups = GroupService();
  final TextEditingController _text = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<SocialPost> _data = [];
  final List<XFile> _images = [];

  List<Map<String, dynamic>> _pendingRequests = [];

  final Set<String> _reviewingRequests = {};

  bool _loading = true;
  bool _loadingRequests = true;
  bool _posting = false;
  bool _joined = false;
  bool _canManageGroup = false;
  bool _isCreator = false;
  bool _joinRequestPending = false;
  bool _membershipUpdating = false;

  int _memberCount = 0;
  String? _myRequestStatus;

  @override
  void initState() {
    super.initState();

    _joined = widget.group.joined;
    _memberCount = widget.group.memberCount;

    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _msg(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // =====================================================
  // LOAD GROUP DATA
  // =====================================================

  Future<void> _load() async {
    try {
      final groupIds = await _groups.getMyGroupIds();
      final isMember = groupIds.contains(widget.group.id);

      final canManage = await _groups.canManageGroup(
        widget.group.id,
      );
      final isCreator = await _groups.isGroupCreator(widget.group.id);

      final statuses = await _groups.getMyJoinRequestStatuses();

      final requestStatus = statuses[widget.group.id];

      final requests = canManage
          ? await _groups.getPendingJoinRequests(widget.group.id)
          : <Map<String, dynamic>>[];

      final posts = isMember
          ? await _posts.getFeed(groupId: widget.group.id)
          : <SocialPost>[];

      final memberCount = await _groups.getMemberCount(
        widget.group.id,
      );

      if (!mounted) return;

      setState(() {
        _joined = isMember;
        _canManageGroup = canManage;
        _isCreator = isCreator;
        _joinRequestPending = requestStatus == 'pending';
        _myRequestStatus = requestStatus;

        _pendingRequests = requests;
        _data = posts;
        _memberCount = memberCount;

        _loading = false;
        _loadingRequests = false;
      });
    } catch (e) {
      debugPrint('GROUP DETAIL LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _loadingRequests = false;
      });

      _msg('Could not load group information: $e');
    }
  }

  // =====================================================
  // DELETE GROUP (CREATOR ONLY)
  // =====================================================

  Future<void> _confirmDeleteGroup() async {
    if (!_isCreator) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this group?'),
        content: const Text(
          'This permanently removes the group and its database records, '
          'including posts, comments, likes, memberships and pending join '
          'requests. This action cannot be undone.',
        ),
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
            child: const Text('Delete group'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _groups.deleteGroup(widget.group.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _msg('Could not delete group: $e');
    }
  }

  // =====================================================
  // JOIN / LEAVE GROUP
  // =====================================================

  Future<void> _membership() async {
    if (_membershipUpdating || _joinRequestPending) return;

    setState(() => _membershipUpdating = true);

    try {
      if (_joined) {
        await _groups.leaveGroup(widget.group.id);

        if (!mounted) return;

        setState(() {
          _joined = false;
          _data.clear();
          _images.clear();
          _text.clear();
        });

        _msg('You left this group.');
        await _load();
      } else {
        await _groups.requestToJoinGroup(widget.group.id);

        if (!mounted) return;

        setState(() {
          _joinRequestPending = true;
          _myRequestStatus = 'pending';
        });

        _msg('Join request sent. Wait for admin approval.');

        await _load();
      }
    } catch (e) {
      _msg('Could not update membership: $e');
    } finally {
      if (mounted) {
        setState(() => _membershipUpdating = false);
      }
    }
  }

  // =====================================================
  // APPROVE / REJECT JOIN REQUESTS
  // =====================================================

  Future<void> _reviewRequest(
      Map<String, dynamic> request,
      bool approve,
      ) async {
    final requestId = request['id'].toString();

    if (_reviewingRequests.contains(requestId)) return;

    setState(() {
      _reviewingRequests.add(requestId);
    });

    try {
      await _groups.reviewJoinRequest(
        requestId: requestId,
        approve: approve,
      );

      _msg(
        approve
            ? 'Join request approved.'
            : 'Join request rejected.',
      );

      await _load();
    } catch (e) {
      _msg('Could not review request: $e');
    } finally {
      if (mounted) {
        setState(() {
          _reviewingRequests.remove(requestId);
        });
      }
    }
  }

  // =====================================================
  // JOIN REQUEST MANAGEMENT SECTION
  // =====================================================

  Widget _joinRequestsSection(ThemeData theme) {
    if (!_canManageGroup) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_alt_1),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Join Requests',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (_pendingRequests.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_pendingRequests.length}',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingRequests)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_pendingRequests.isEmpty)
            Text(
              'No pending join requests.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ..._pendingRequests.map((request) {
              final model = JoinRequest.fromMap(request);

              return JoinRequestTile(
                request: model,
                busy: _reviewingRequests.contains(model.id),
                showGroupName: false,
                onApprove: () => _reviewRequest(request, true),
                onReject: () => _reviewRequest(request, false),
              );
            }),
        ],
      ),
    );
  }

  // =====================================================
  // PICK IMAGES
  // =====================================================

  Future<void> _pick() async {
    if (_images.length >= 5) {
      _msg('You can add a maximum of 5 photos.');
      return;
    }

    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 2000,
      );

      if (!mounted || files.isEmpty) return;

      final remaining = 5 - _images.length;

      setState(() {
        _images.addAll(files.take(remaining));
      });

      if (files.length > remaining) {
        _msg('Only 5 photos can be added to one post.');
      }
    } catch (e) {
      _msg('Could not select photos: $e');
    }
  }

  // =====================================================
  // PUBLISH GROUP POST
  // =====================================================

  Future<void> _publish() async {
    if (_posting || !_joined) return;

    final content = _text.text.trim();

    if (content.isEmpty && _images.isEmpty) {
      _msg('Write something or add a photo.');
      return;
    }

    setState(() => _posting = true);

    try {
      final batch =
      <({String name, Uint8List bytes, String mime})>[];

      for (final file in _images) {
        final extension = file.name.split('.').last.toLowerCase();

        final mime = switch (extension) {
        'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
    };

    batch.add((
    name: file.name,
    bytes: await file.readAsBytes(),
    mime: mime,
    ));
    }

    final urls = batch.isEmpty
    ? <String>[]
        : await _posts.uploadPostImages(batch);

    await _posts.createPost(
    content,
    imageUrls: urls,
    groupId: widget.group.id,
    );

    if (!mounted) return;

    setState(() {
    _text.clear();
    _images.clear();
    });

    _msg('Post published successfully.');

    await _load();
    } catch (e) {
    _msg('Could not publish post: $e');
    } finally {
    if (mounted) {
    setState(() => _posting = false);
    }
    }
  }

  // =====================================================
  // IMAGE PREVIEWS
  // =====================================================

  Widget _imagePreviews() {
    if (_images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_images.length, (index) {
          final file = _images[index];

          return FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: snapshot.hasData
                        ? Image.memory(
                      snapshot.data!,
                      width: 65,
                      height: 65,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 65,
                      height: 65,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () {
                        setState(() => _images.removeAt(index));
                      },
                      child: const Icon(
                        Icons.cancel,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }

  // =====================================================
  // POST COMPOSER
  // =====================================================

  Widget _composer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'Share something with this group...',
              counterText: '',
              border: InputBorder.none,
              filled: false,
            ),
          ),
          _imagePreviews(),
          Row(
            children: [
              TextButton.icon(
                onPressed: _posting ? null : _pick,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Photo'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _posting ? null : _publish,
                child: Text(_posting ? 'Posting...' : 'Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(SocialPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This will permanently remove the post and its comments and likes.'),
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
      await _posts.deletePost(post.id);
      await _load();
      if (mounted) _msg('Post deleted.');
    } catch (e) {
      _msg('Could not delete post: $e');
    }
  }

  // =====================================================
  // GROUP POST CARD
  // =====================================================

  Widget _postCard(ThemeData theme, SocialPost post) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName ?? 'Nook student',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      post.createdAt.toString(),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (post.userId == _userId)
                PopupMenuButton<String>(
                  tooltip: 'Post options',
                  onSelected: (value) {
                    if (value == 'delete') _deletePost(post);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete post')),
                  ],
                  icon: const Icon(Icons.more_horiz),
                ),
            ],
          ),
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.content,
              style: theme.textTheme.bodyLarge,
            ),
          ],
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: post.imageUrls.map((url) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        width: 190,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 190,
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  try {
                    await _posts.toggleLike(post);
                    await _load();
                  } catch (e) {
                    _msg('Could not update like: $e');
                  }
                },
                icon: Icon(
                  post.likedByMe
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: post.likedByMe
                      ? Colors.red
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text('${post.likeCount}'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PostCommentsScreen(
                        postId: post.id,
                      ),
                    ),
                  ).then((_) => _load());
                },
                icon: const Icon(Icons.comment_outlined),
                label: Text('${post.commentCount}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BUILD SCREEN
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.group;

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          if (_isCreator)
            IconButton(
              tooltip: 'Delete group',
              onPressed: _confirmDeleteGroup,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.groups_rounded,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            group.name,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Text(
                              group.description.isEmpty
                                  ? 'A place for students to connect and share.'
                                  : group.description,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_memberCount members',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _membershipUpdating || _joinRequestPending
                                ? null
                                : _membership,
                            icon: _membershipUpdating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(
                                    _joined
                                        ? Icons.check
                                        : _joinRequestPending
                                            ? Icons.hourglass_top
                                            : Icons.add,
                                  ),
                            label: Text(
                              _joined
                                  ? 'Joined · Leave group'
                                  : _joinRequestPending
                                      ? 'Request Pending'
                                      : _myRequestStatus == 'rejected'
                                          ? 'Request Again'
                                          : 'Request to Join',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Only the creator/admin can see this section.
                    if (_canManageGroup) ...[
                      const SizedBox(height: 18),
                      _joinRequestsSection(theme),
                    ],

                    // Only approved members can publish posts.
                    if (_joined) ...[
                      const SizedBox(height: 18),
                      _composer(theme),
                    ],

                    const SizedBox(height: 22),
                    Text(
                      'Group discussion',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_data.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _joined
                          ? 'No posts yet. Start the discussion!'
                          : _joinRequestPending
                          ? 'Your join request is waiting for approval.'
                          : 'Request to join this group to see its posts.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _postCard(theme, _data[index]),
                      );
                    },
                    childCount: _data.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}