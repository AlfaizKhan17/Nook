import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  Future<String> uploadItemImage({
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final path = 'items/${_uuid.v4()}.$extension';

    await _supabase.storage.from('item-images').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: false,
        contentType: contentType,
      ),
    );

    return _supabase.storage.from('item-images').getPublicUrl(path);
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('item-images');
      if (bucketIndex == -1) return;

      final filePath = segments.sublist(bucketIndex + 1).join('/');
      await _supabase.storage.from('item-images').remove([filePath]);
    } catch (_) {
      // A storage cleanup failure must not block the database operation.
    }
  }
}
