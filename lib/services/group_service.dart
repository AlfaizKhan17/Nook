
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campus_group.dart';
import '../models/join_request.dart';

class GroupService {

  Future<bool> isGroupCreator(String groupId) async {
    final group = await _db
        .from('groups')
        .select('created_by')
        .eq('id', groupId)
        .maybeSingle();

    return group?['created_by']?.toString() == _userId;
  }

  Future<void> deleteGroup(String groupId) async {
    // The UI check is for convenience only; the database RLS policy is
    // the final authorization boundary.
    if (!await isGroupCreator(groupId)) {
      throw Exception('Only the group creator can delete this group.');
    }

    final deleted = await _db
        .from('groups')
        .delete()
        .eq('id', groupId)
        .eq('created_by', _userId)
        .select('id')
        .maybeSingle();

    if (deleted == null) {
      throw Exception('The group was not deleted. Check your permissions and try again.');
    }
  }

  Future<bool> canManageGroup(String groupId) async {
    final userId = _userId;

    // The group creator can manage the group.
    final group = await _db
        .from('groups')
        .select('created_by')
        .eq('id', groupId)
        .maybeSingle();

    if (group?['created_by']?.toString() == userId) {
      return true;
    }

    // An admin member can also manage the group.
    final membership = await _db
        .from('group_members')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    return membership?['role'] == 'admin';
  }
  final SupabaseClient _db = Supabase.instance.client;

  String get _userId {
    final id = _db.auth.currentUser?.id;

    if (id == null) {
      throw Exception('Please sign in first.');
    }

    return id;
  }

  // =====================================================
  // GET CAMPUS GROUPS
  // =====================================================

  Future<List<CampusGroup>> getCampusGroups() async {
    final groupsResult = await _db
        .from('groups')
        .select()
        .order('created_at', ascending: false);

    final membersResult = await _db
        .from('group_members')
        .select('group_id, user_id');

    final groups = List<Map<String, dynamic>>.from(groupsResult);
    final members = List<Map<String, dynamic>>.from(membersResult);

    final result = groups.map((group) {
      final groupId = group['id'].toString();

      final groupMembers = members
          .where((member) =>
      member['group_id'].toString() == groupId)
          .map((member) => {
        'user_id': member['user_id'],
      })
          .toList();

      return {
        ...group,
        'group_members': groupMembers,
      };
    }).toList();

    return result
        .map((group) => CampusGroup.fromMap(group, _userId))
        .toList();
  }

  // =====================================================
  // GENERAL GROUP METHODS
  // =====================================================

  Future<List<Map<String, dynamic>>> getGroups() async {
    final result = await _db
        .from('groups')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(result);
  }

  Future<Set<String>> getMyGroupIds() async {
    final result = await _db
        .from('group_members')
        .select('group_id')
        .eq('user_id', _userId);

    return result
        .map<String>((row) => row['group_id'].toString())
        .toSet();
  }

  Future<int> getMemberCount(String groupId) async {
    final result = await _db
        .from('group_members')
        .select('group_id')
        .eq('group_id', groupId);

    return result.length;
  }

  // =====================================================
  // CREATE GROUP
  // =====================================================

  Future<void> createGroup({
    required String name,
    required String description,
  }) async {
    final userId = _userId;

    final group = await _db
        .from('groups')
        .insert({
      'name': name.trim(),
      'description': description.trim(),
      'created_by': userId,
    })
        .select('id')
        .single();

    // The creator becomes the initial group admin.
    await _db.from('group_members').insert({
      'group_id': group['id'],
      'user_id': userId,
      'role': 'admin',
    });
  }

  // =====================================================
  // GROUP JOIN REQUESTS
  // =====================================================

  // Request membership instead of directly joining.
  Future<void> requestToJoinGroup(String groupId) async {
    await _db.from('group_join_requests').insert({
      'group_id': groupId,
      'user_id': _userId,
      'status': 'pending',
    });
  }

  // Compatibility method for any older screen that
  // still calls joinGroup(). It now sends a request.
  @Deprecated('Use requestToJoinGroup instead.')
  Future<void> joinGroup(String groupId) async {
    await requestToJoinGroup(groupId);
  }

  // Get the current user's latest request status
  // for each group.
  Future<Map<String, String>> getMyJoinRequestStatuses() async {
    final result = await _db
        .from('group_join_requests')
        .select('group_id, status, created_at')
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    final statuses = <String, String>{};

    for (final row in result) {
      final groupId = row['group_id'].toString();

      // Keep the newest request for each group.
      statuses.putIfAbsent(
        groupId,
            () => row['status'].toString(),
      );
    }

    return statuses;
  }

  // Get pending requests for a particular group.
  // The database RLS policy restricts this to
  // the group creator and admins.
  Future<List<Map<String, dynamic>>> getPendingJoinRequests(
      String groupId,
      ) async {
    final result = await _db
        .from('group_join_requests')
        .select('*, profiles!group_join_requests_user_id_fkey(name)')
        .eq('group_id', groupId)
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(result);
  }

  // Pending requests from other students across EVERY group the current user
  // manages (as creator or admin), oldest first.
  //
  // The RLS policy on group_join_requests only returns rows for groups the user
  // manages, plus the user's own outgoing requests. The `neq` removes those
  // outgoing ones so the inbox only shows requests that need a decision.
  Future<List<JoinRequest>> getPendingRequestsForManagedGroups() async {
    final result = await _db
        .from('group_join_requests')
        .select('*, groups(name), profiles!group_join_requests_user_id_fkey(name)')
        .eq('status', 'pending')
        .neq('user_id', _userId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(result)
        .map(JoinRequest.fromMap)
        .toList();
  }

  // Approve or reject a join request.
  // Uses the secure PostgreSQL function.
  Future<void> reviewJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    await _db.rpc(
      'review_group_join_request',
      params: {
        'p_request_id': requestId,
        'p_decision': approve ? 'approved' : 'rejected',
      },
    );
  }

  // =====================================================
  // LEAVE GROUP
  // =====================================================

  Future<void> leaveGroup(String groupId) async {
    await _db
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', _userId);
  }

  // =====================================================
  // GROUP POSTS
  // =====================================================

  Future<List<Map<String, dynamic>>> getGroupPosts(
      String groupId,
      ) async {
    final result = await _db
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(name)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> createGroupPost({
    required String groupId,
    required String content,
  }) async {
    await _db.from('posts').insert({
      'user_id': _userId,
      'group_id': groupId,
      'content': content.trim(),
      'visibility': 'community',
    });
  }
}
