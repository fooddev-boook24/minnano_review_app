import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kKey = 'share_unlocked_date';

class ShareUnlockService {
  Future<bool> isUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kKey);
    if (saved == null) return false;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return saved == today;
  }

  Future<void> unlock() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString(_kKey, today);
  }
}
