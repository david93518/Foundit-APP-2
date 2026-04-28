/// QR 防丟貼紙 — 對齊後端 QrItem entity（snake_case）
class QrItemModel {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String qrCode;
  final String qrImageUrl;
  final DateTime createdAt;

  const QrItemModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    required this.qrCode,
    this.qrImageUrl = '',
    required this.createdAt,
  });

  factory QrItemModel.fromJson(Map<String, dynamic> json) {
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

    return QrItemModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      qrCode: json['qr_code']?.toString() ?? json['qrCode']?.toString() ?? '',
      qrImageUrl: json['qr_image_url']?.toString() ??
          json['qrImageUrl']?.toString() ??
          '',
      createdAt: ts(json['created_at'] ?? json['createdAt']),
    );
  }

  /// 從 qrCode 內容（`<baseUrl>/qr/<uuid>`）取出末段 uuid，給 scanByCode 使用
  String get rawCode {
    final i = qrCode.lastIndexOf('/');
    if (i < 0) return qrCode;
    return qrCode.substring(i + 1);
  }
}

class QrScanResult {
  final QrItemModel qrItem;
  final String ownerId;
  final String ownerName;
  final String ownerAvatar;
  final String ownerPhone;

  const QrScanResult({
    required this.qrItem,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatar = '',
    this.ownerPhone = '',
  });

  factory QrScanResult.fromJson(Map<String, dynamic> json) {
    final qrJson = (json['qr_item'] ?? json['qrItem']) as Map<String, dynamic>?;
    final ownerJson = json['owner'] as Map<String, dynamic>?;
    return QrScanResult(
      qrItem: QrItemModel.fromJson(qrJson ?? const {}),
      ownerId: ownerJson?['id']?.toString() ?? '',
      ownerName: ownerJson?['name']?.toString() ?? '',
      ownerAvatar: ownerJson?['avatar_url']?.toString() ??
          ownerJson?['avatarUrl']?.toString() ??
          '',
      ownerPhone: ownerJson?['phone']?.toString() ?? '',
    );
  }
}
