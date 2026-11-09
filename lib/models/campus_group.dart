class CampusGroup {
  final String id, name, description, createdBy;
  final int memberCount;
  final bool joined;
  final DateTime createdAt;
  const CampusGroup({required this.id, required this.name, required this.description,
    required this.createdBy, required this.memberCount, required this.joined, required this.createdAt});
  factory CampusGroup.fromMap(Map<String,dynamic> map, String userId) {
    final members = map['group_members'] as List<dynamic>? ?? const [];
    return CampusGroup(
      id: map['id'].toString(), name: map['name']?.toString() ?? 'Campus group',
      description: map['description']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? '',
      memberCount: members.length,
      joined: members.any((m) => (m as Map)['user_id']?.toString() == userId),
      createdAt: DateTime.parse(map['created_at'].toString()).toLocal(),
    );
  }
}
