import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item_model.dart';

class ItemService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _select = '*, profiles(name, email, phone)';

  /// PostgREST's `or()` filter is a comma/parenthesis-delimited string, so those
  /// characters (and wildcards) in a user's search text would break the query.
  static String _sanitizeSearch(String raw) =>
      raw.replaceAll(RegExp(r'[,()%*\\"]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<List<ItemModel>> getItems({String search = ''}) async {
    final value = _sanitizeSearch(search);

    var query = _supabase.from('items').select(_select).eq('status', 'ACTIVE');
    if (value.isNotEmpty) {
      query = query.or(
        'title.ilike.%$value%,'
        'description.ilike.%$value%,'
        'location.ilike.%$value%',
      );
    }
    final response = await query.order('created_at', ascending: false);

    return (response as List).map((item) => ItemModel.fromMap(item)).toList();
  }

  Future<List<ItemModel>> getMyPosts() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    final response = await _supabase
        .from('items')
        .select(_select)
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (response as List).map((item) => ItemModel.fromMap(item)).toList();
  }

  Future<ItemModel> createItem({
    required String title,
    required String type,
    required String location,
    required String description,
    String? imageUrl,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final response = await _supabase
        .from('items')
        .insert({
          'user_id': user.id,
          'title': title,
          'type': type,
          'location': location,
          'description': description,
          'image_url': imageUrl,
          'status': 'ACTIVE',

          // Automatic date/time.
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select(_select)
        .single();

    return ItemModel.fromMap(response);
  }

  /// Row Level Security makes a blocked write succeed with zero affected rows,
  /// so ask for the affected rows back and treat "none" as a failure instead of
  /// telling the user it worked.
  Future<void> deleteItem(String itemId) async {
    final rows = await _supabase.from('items').delete().eq('id', itemId).select('id');
    if (rows.isEmpty) {
      throw Exception('This post could not be deleted. You can only delete your own posts.');
    }
  }

  Future<void> markResolved(String itemId) async {
    final rows = await _supabase
        .from('items')
        .update({'status': 'RESOLVED'})
        .eq('id', itemId)
        .select('id');
    if (rows.isEmpty) {
      throw Exception('This post could not be updated. You can only update your own posts.');
    }
  }
}
