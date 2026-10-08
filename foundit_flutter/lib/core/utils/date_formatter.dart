import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  /// 相對時間（剛剛 / 10 分鐘前 / 3 小時前 / 昨天 / 3/15）
  static String relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return DateFormat('M/d').format(dt);
  }

  /// 完整時間（2025/03/15 14:30）
  static String full(DateTime dt) => DateFormat('yyyy/MM/dd HH:mm').format(dt);

  /// 日期（3月15日）
  static String date(DateTime dt) => DateFormat('M月d日', 'zh_TW').format(dt);

  /// 聊天室訊息時間（14:30）
  static String time(DateTime dt) => DateFormat('HH:mm').format(dt);
}

class CurrencyFormatter {
  CurrencyFormatter._();

  static String twd(num amount) {
    final f = NumberFormat('#,##0');
    return 'NT\$ ${f.format(amount)}';
  }
}

class Greeting {
  Greeting._();

  static String forNow({String? name}) {
    final h = DateTime.now().hour;
    final prefix = h < 5
        ? '夜深了'
        : h < 11
        ? '早安'
        : h < 14
        ? '午安'
        : h < 18
        ? '下午好'
        : '晚安';
    return name == null || name.isEmpty ? '$prefix 👋' : '$prefix，$name';
  }
}
