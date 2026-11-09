
class SocialPost {
  final String id, userId, content;
  final DateTime createdAt;
  final String? authorName;
  final int likeCount, commentCount;
  final bool likedByMe;
  final List<String> imageUrls;
  final String? groupId, groupName;
  const SocialPost({required this.id, required this.userId, required this.content,
    required this.createdAt, this.authorName, required this.likeCount,
    required this.commentCount, required this.likedByMe,
    this.imageUrls = const [], this.groupId, this.groupName});
  factory SocialPost.fromMap(Map<String, dynamic> map, String currentUserId) {
    final profile = map['profiles'];
    final likes = map['post_likes'] as List<dynamic>? ?? const [];
    final comments = map['comments'] as List<dynamic>? ?? const [];
    final count = comments.isEmpty ? 0 : ((comments.first as Map)['count'] as int? ?? 0);
    final group = map['groups'];
    return SocialPost(
      id: map['id'].toString(), userId: map['user_id'].toString(),
      content: map['content'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'].toString()).toLocal(),
      authorName: profile is Map ? profile['name'] as String? : null,
      likeCount: likes.length, commentCount: count,
      likedByMe: likes.any((x) => (x as Map)['user_id']?.toString() == currentUserId),
      imageUrls: (map['image_urls'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
      groupId: map['group_id']?.toString(),
      groupName: group is Map ? group['name']?.toString() : null,
    );
  }
}
