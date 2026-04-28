class AppUser {
  final String id;
  final String phone;
  final String name;
  final String avatarUrl;
  final String bio;
  final String email;
  final DateTime createdAt;
  final int points;
  final bool isVerified;

  const AppUser({
    required this.id,
    this.phone = '',
    this.name = '',
    this.avatarUrl = '',
    this.bio = '',
    this.email = '',
    required this.createdAt,
    this.points = 0,
    this.isVerified = false,
  });

  AppUser copyWith({
    String? id,
    String? phone,
    String? name,
    String? avatarUrl,
    String? bio,
    String? email,
    DateTime? createdAt,
    int? points,
    bool? isVerified,
  }) {
    return AppUser(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      points: points ?? this.points,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime ts(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return DateTime.fromMillisecondsSinceEpoch(p);
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return AppUser(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString() ??
          json['avatar_url']?.toString() ??
          '',
      bio: json['bio']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      createdAt: ts(json['createdAt'] ?? json['created_at']),
      points: (json['points'] as num?)?.toInt() ?? 0,
      isVerified: json['isVerified'] as bool? ??
          json['is_verified'] as bool? ??
          false,
    );
  }
}

/// 個人頁面的統計數字
class UserStats {
  final int posted;
  final int helpful;
  final int bookmarks;
  final int foundCount;
  final int lostCount;

  const UserStats({
    this.posted = 0,
    this.helpful = 0,
    this.bookmarks = 0,
    this.foundCount = 0,
    this.lostCount = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return UserStats(
      posted: n('posted'),
      helpful: n('helpful'),
      bookmarks: n('bookmarks'),
      foundCount: n('found_count'),
      lostCount: n('lost_count'),
    );
  }
}

/// 成就徽章
class BadgeInfo {
  final String code;
  final String name;
  final String emoji;
  final bool unlocked;
  final double progress;
  final String description;

  const BadgeInfo({
    required this.code,
    required this.name,
    required this.emoji,
    required this.unlocked,
    required this.progress,
    required this.description,
  });

  factory BadgeInfo.fromJson(Map<String, dynamic> json) {
    return BadgeInfo(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🏅',
      unlocked: json['unlocked'] as bool? ?? false,
      progress: ((json['progress'] as num?) ?? 0).toDouble(),
      description: json['description']?.toString() ?? '',
    );
  }
}
