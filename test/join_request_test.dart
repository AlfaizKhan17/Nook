import 'package:flutter_test/flutter_test.dart';
import 'package:nook/models/join_request.dart';

void main() {
  group('JoinRequest.fromMap', () {
    test('parses a row with embedded group and requester', () {
      final request = JoinRequest.fromMap({
        'id': 'r1',
        'group_id': 'g1',
        'user_id': 'u1',
        'status': 'pending',
        'created_at': '2026-11-08T10:00:00+00:00',
        'groups': {'name': 'Coding Club'},
        'profiles': {'name': 'Student One'},
      });
      expect(request.id, 'r1');
      expect(request.groupId, 'g1');
      expect(request.groupName, 'Coding Club');
      expect(request.requesterName, 'Student One');
      expect(request.userId, 'u1');
      expect(request.createdAt?.toUtc(), DateTime.utc(2026, 11, 8, 10));
    });

    test('falls back when embeds are missing, blank or malformed', () {
      final request = JoinRequest.fromMap({
        'id': 'r2',
        'group_id': 'g1',
        'user_id': 'u2',
        'created_at': 'not a date',
        'groups': null,
        'profiles': {'name': '   '},
      });
      expect(request.groupName, '');
      expect(request.groupLabel, 'the group');
      expect(request.requesterName, 'Student');
      expect(request.createdAt, isNull);
    });

    test('groupLabel uses the group name when present', () {
      final request = JoinRequest.fromMap({
        'id': 'r3',
        'user_id': 'u3',
        'groups': {'name': 'Photography Club'},
      });
      expect(request.groupLabel, 'Photography Club');
    });
  });
}
