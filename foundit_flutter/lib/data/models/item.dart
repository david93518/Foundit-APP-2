enum ItemType {
  lost('lost', '遺失物'),
  found('found', '撿到物');

  final String code;
  final String label;
  const ItemType(this.code, this.label);

  static ItemType fromCode(String? v) {
    return ItemType.values.firstWhere(
      (e) => e.code == v?.toLowerCase(),
      orElse: () => ItemType.lost,
    );
  }
}

enum ItemStatus {
  active('active', '尋找中'),
  resolved('resolved', '已找到'),
  closed('closed', '已關閉');

  final String code;
  final String label;
  const ItemStatus(this.code, this.label);

  static ItemStatus fromCode(String? v) {
    return ItemStatus.values.firstWhere(
      (e) => e.code == v?.toLowerCase(),
      orElse: () => ItemStatus.active,
    );
  }
}

class Item {
  final String id;
  final ItemType type;
  final String userId;
  final String userName;
  final String userAvatar;
  final bool userVerified;
  final String title;
  final String category;
  final String description;
  final String color;
  final List<String> images;
  final double latitude;
  final double longitude;
  final String locationName;
  final DateTime lostAt;
  final int reward;
  final bool hasReward;
  final String storageLocation;
  final bool handedToPolice;
  final ItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Item({
    required this.id,
    required this.type,
    this.userId = '',
    this.userName = '',
    this.userAvatar = '',
    this.userVerified = false,
    required this.title,
    required this.category,
    this.description = '',
    this.color = '',
    this.images = const [],
    this.latitude = 0,
    this.longitude = 0,
    this.locationName = '',
    required this.lostAt,
    this.reward = 0,
    this.hasReward = false,
    this.storageLocation = '',
    this.handedToPolice = false,
    this.status = ItemStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    DateTime _ts(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return DateTime.fromMillisecondsSinceEpoch(p);
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return Item(
      id: json['id']?.toString() ?? '',
      type: ItemType.fromCode(json['type']?.toString()),
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? json['userName']?.toString() ?? '',
      userAvatar: json['user_avatar']?.toString() ?? json['userAvatar']?.toString() ?? '',
      userVerified: json['user_verified'] as bool? ??
          json['userVerified'] as bool? ??
          false,
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      locationName: json['location_name']?.toString() ?? json['locationName']?.toString() ?? '',
      lostAt: _ts(json['lost_at'] ?? json['lostAt']),
      reward: (json['reward'] as num?)?.toInt() ?? 0,
      hasReward: json['has_reward'] as bool? ?? json['hasReward'] as bool? ?? false,
      storageLocation: json['storage_location']?.toString() ?? json['storageLocation']?.toString() ?? '',
      handedToPolice: json['handed_to_police'] as bool? ?? json['handedToPolice'] as bool? ?? false,
      status: ItemStatus.fromCode(json['status']?.toString()),
      createdAt: _ts(json['created_at'] ?? json['createdAt']),
      updatedAt: _ts(json['updated_at'] ?? json['updatedAt']),
    );
  }

  /// 依後端 CreateItemDto 的長度上限截斷，避免地圖帶入的長地址造成整筆 400。
  static String _clip(String value, int max) {
    final text = value.trim();
    return text.length <= max ? text : text.substring(0, max);
  }

  Map<String, dynamic> toCreateJson() => {
        'type': type.code,
        'title': _clip(title, 100),
        'category': _clip(category, 50),
        'description': _clip(description, 2000),
        'color': _clip(color, 30),
        'images': images,
        if (!(latitude == 0 && longitude == 0)) 'latitude': latitude,
        if (!(latitude == 0 && longitude == 0)) 'longitude': longitude,
        'locationName': _clip(locationName, 200),
        'lostAt': lostAt.millisecondsSinceEpoch,
        'reward': reward,
        'hasReward': hasReward,
        'storageLocation': _clip(storageLocation, 200),
        'handedToPolice': handedToPolice,
        'termsAccepted': true,
        'termsVersion': '2026-10-04',
      };
}
