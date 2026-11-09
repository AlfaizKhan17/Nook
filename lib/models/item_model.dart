class ItemModel {
  final String id;
  final String userId;
  final String title;
  final String type;
  final String location;
  final String description;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;

  final String? userName;
  final String? userEmail;
  final String? userPhone;

  ItemModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
    required this.location,
    required this.description,
    required this.imageUrl,
    required this.status,
    required this.createdAt,
    this.userName,
    this.userEmail,
    this.userPhone,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'];

    return ItemModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      type: map['type'] ?? '',
      location: map['location'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'],
      status: map['status'] ?? 'ACTIVE',
      createdAt: DateTime.parse(map['created_at']),
      userName: profile != null ? profile['name'] : null,
      userEmail: profile != null ? profile['email'] : null,
      userPhone: profile != null ? profile['phone'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'type': type,
      'location': location,
      'description': description,
      'image_url': imageUrl,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}