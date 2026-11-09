import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/social_post.dart';

class SocialPostService {
  final SupabaseClient _client = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Please sign in first.');
    return id;
  }

  static const _postSelection = '''
    id,user_id,content,image_urls,group_id,created_at,
    profiles!posts_user_id_fkey(name),
    post_likes(user_id),
    comments(count),
    groups(name)
  ''';

  /// The campus feed contains only public posts that are not attached to a group.
  /// Group posts are loaded only from their own group detail page.
  Future<List<SocialPost>> getFeed({int limit = 50, String? groupId}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    var query = _client.from('posts').select(_postSelection);
    if (groupId == null) {
      query = query.eq('visibility', 'public').isFilter('group_id', null);
    } else {
      query = query.eq('group_id', groupId);
    }

    final rows = await query.order('created_at', ascending: false).limit(limit);
    return (rows as List)
        .map((row) => SocialPost.fromMap(row as Map<String, dynamic>, user.id))
        .toList();
  }

  Future<List<SocialPost>> getMySocialPosts() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('posts')
        .select(_postSelection)
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => SocialPost.fromMap(row as Map<String, dynamic>, user.id))
        .toList();
  }

  Future<List<String>> uploadPostImages(
    List<({String name, Uint8List bytes, String mime})> files,
  ) async {
    final userId = _userId;
    final urls = <String>[];

    for (final file in files) {
      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
      final path = '$userId/${_uuid.v4()}.$ext';

      await _client.storage.from('post-images').uploadBinary(
        path,
        file.bytes,
        fileOptions: FileOptions(contentType: file.mime, upsert: false),
      );
      urls.add(_client.storage.from('post-images').getPublicUrl(path));
    }
    return urls;
  }

  Future<void> createPost(
    String content, {
    List<String> imageUrls = const [],
    String? groupId,
  }) async {
    final value = content.trim();
    if (value.isEmpty && imageUrls.isEmpty) {
      throw Exception('Add text or at least one photo.');
    }

    await _client.from('posts').insert({
      'user_id': _userId,
      'content': value,
      'visibility': groupId == null ? 'public' : 'community',
      'image_urls': imageUrls,
      'group_id': groupId,
    });
  }

  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId).eq('user_id', _userId);
  }

  Future<void> toggleLike(SocialPost post) async {
    final userId = _userId;
    if (post.likedByMe) {
      await _client
          .from('post_likes')
          .delete()
          .eq('post_id', post.id)
          .eq('user_id', userId);
    } else {
      await _client.from('post_likes').insert({
        'post_id': post.id,
        'user_id': userId,
      });
    }
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final rows = await _client
        .from('comments')
        .select('''
          id,user_id,content,parent_comment_id,created_at,
          profiles!comments_user_id_fkey(name)
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> addComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    final value = content.trim();
    if (value.isEmpty) return;
    if (value.length > 1000) {
      throw Exception('Comments must be 1,000 characters or fewer.');
    }

    await _client.from('comments').insert({
      'post_id': postId,
      'user_id': _userId,
      'content': value,
      'parent_comment_id': parentCommentId,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _client
        .from('comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', _userId);
  }
}
