import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's search-history list on-device. Reuses
/// flutter_secure_storage since that's already this app's general local
/// store (see account_storage.dart) — no new dependency needed for a
/// handful of short strings.
class RecentSearchesStorage {
  const RecentSearchesStorage();

  static const _storage = FlutterSecureStorage();
  static const _key = 'recent_searches';

  Future<List<String>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<String>();
  }

  Future<void> save(List<String> searches) async {
    await _storage.write(key: _key, value: jsonEncode(searches));
  }
}
