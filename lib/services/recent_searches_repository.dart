import 'package:flutter/foundation.dart';
import 'recent_searches_storage.dart';

/// The user's actual search history, shown on the empty search screen.
/// Most-recent-first, deduplicated case-insensitively, capped so the list
/// stays scannable. Same singleton + ChangeNotifier shape as
/// AccountRepository.
class RecentSearchesRepository extends ChangeNotifier {
  RecentSearchesRepository._();
  static final instance = RecentSearchesRepository._();

  static const _maxEntries = 8;

  final _storage = const RecentSearchesStorage();

  List<String> _searches = [];
  List<String> get searches => List.unmodifiable(_searches);

  Future<void> load() async {
    _searches = await _storage.load();
    notifyListeners();
  }

  Future<void> record(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _searches.removeWhere((s) => s.toLowerCase() == trimmed.toLowerCase());
    _searches.insert(0, trimmed);
    if (_searches.length > _maxEntries) {
      _searches = _searches.sublist(0, _maxEntries);
    }
    await _storage.save(_searches);
    notifyListeners();
  }

  Future<void> clear() async {
    _searches = [];
    await _storage.save(_searches);
    notifyListeners();
  }
}
