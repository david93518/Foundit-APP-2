import '../api/api_client.dart';

class BlockedContact {
  const BlockedContact({required this.id, required this.name});
  final String id;
  final String name;
}

class SafetyRepository {
  SafetyRepository(this.api);
  final ApiClient api;

  Future<List<BlockedContact>> blockedContacts() async {
    final response = await api.get<Map<String, dynamic>>('/blocks');
    return (response.data?['data'] as List? ?? [])
        .map(
          (row) => BlockedContact(
            id: row['user_id'] as String,
            name: (row['name'] as String?) ?? '使用者',
          ),
        )
        .toList();
  }

  Future<void> block(String userId) async {
    await api.post('/blocks', data: {'userId': userId});
  }

  Future<void> unblock(String userId) async {
    await api.delete('/blocks/$userId');
  }

  Future<void> reportUser(String userId, String reason) async {
    await api.post(
      '/reports',
      data: {'targetType': 'user', 'targetId': userId, 'reason': reason},
    );
  }
}
