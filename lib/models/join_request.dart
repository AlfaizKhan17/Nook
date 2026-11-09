/// A pending request from a student to join a campus group.
class JoinRequest {
  final String id;
  final String groupId;

  /// Empty when the query did not include the group (e.g. inside a group's own
  /// screen, where the group is already known).
  final String groupName;
  final String userId;
  final String requesterName;
  final DateTime? createdAt;

  const JoinRequest({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.userId,
    required this.requesterName,
    required this.createdAt,
  });

  /// Name to use in sentences such as "Sam was added to <group>".
  String get groupLabel => groupName.isEmpty ? 'the group' : groupName;

  /// Parses a `group_join_requests` row, optionally with embedded
  /// `groups(name)` and `profiles(name)` objects.
  factory JoinRequest.fromMap(Map<String, dynamic> map) {
    String text(dynamic value, String fallback) {
      final result = value?.toString().trim() ?? '';
      return result.isEmpty ? fallback : result;
    }

    final profile = map['profiles'];
    final group = map['groups'];

    return JoinRequest(
      id: map['id'].toString(),
      groupId: map['group_id']?.toString() ?? '',
      groupName: group is Map ? text(group['name'], '') : '',
      userId: map['user_id']?.toString() ?? '',
      requesterName: profile is Map ? text(profile['name'], 'Student') : 'Student',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal(),
    );
  }
}
