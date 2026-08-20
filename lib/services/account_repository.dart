import 'package:flutter/foundation.dart';
import '../models/linked_account.dart';
import 'account_storage.dart';
import 'oauth_service.dart';

/// Single source of truth for linked accounts, shared across the Home and
/// Stacks screens. Deliberately a plain singleton + ChangeNotifier — this
/// app has one user and one account list, so a state-management package
/// would be overhead, not a simplification.
class AccountRepository extends ChangeNotifier {
  AccountRepository._();
  static final instance = AccountRepository._();

  final _oauth = const OAuthService();
  final _storage = const AccountStorage();

  List<LinkedAccount> _accounts = [];
  List<LinkedAccount> get accounts => List.unmodifiable(_accounts);

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final stored = await _storage.loadAccounts();
    _accounts = stored
        .map((m) => LinkedAccount(
              email: m.email,
              googleName: m.name ?? m.email,
              customLabel: m.customLabel,
              inkIndex: m.inkIndex,
              linkedAt: m.linkedAt,
              refreshFailed: m.refreshFailed,
            ))
        .toList();
    _loaded = true;
    notifyListeners();
  }

  /// Opens Google sign-in for a brand-new account and adds it to the list.
  Future<void> linkNewAccount() async {
    final tokens = await _oauth.linkAccount();
    final inkIndex = _accounts.length;
    final existing = _accounts.where((a) => a.email == tokens.email);
    final meta = StoredAccountMeta(
      email: tokens.email,
      name: tokens.name,
      customLabel: existing.isEmpty ? null : existing.first.customLabel,
      inkIndex: inkIndex,
      linkedAt: DateTime.now(),
      refreshFailed: false,
    );
    await _storage.upsertAccount(meta, refreshToken: tokens.refreshToken);
    _accounts.removeWhere((a) => a.email == tokens.email);
    _accounts.add(LinkedAccount(
      email: meta.email,
      googleName: meta.name ?? meta.email,
      customLabel: meta.customLabel,
      inkIndex: meta.inkIndex,
      linkedAt: meta.linkedAt,
    ));
    notifyListeners();
  }

  /// Re-runs sign-in for an already-linked account (the reconnect flow),
  /// keeping its existing ink so it doesn't visually "become a new account."
  Future<void> reconnectAccount(String email) async {
    final existing = _accounts.firstWhere((a) => a.email == email);
    final tokens = await _oauth.linkAccount();
    final meta = StoredAccountMeta(
      email: existing.email,
      name: tokens.name,
      customLabel: existing.customLabel,
      inkIndex: existing.inkIndex,
      linkedAt: DateTime.now(),
      refreshFailed: false,
    );
    await _storage.upsertAccount(meta, refreshToken: tokens.refreshToken);
    final index = _accounts.indexWhere((a) => a.email == email);
    _accounts[index] = LinkedAccount(
      email: meta.email,
      googleName: meta.name ?? meta.email,
      customLabel: meta.customLabel,
      inkIndex: meta.inkIndex,
      linkedAt: meta.linkedAt,
    );
    notifyListeners();
  }

  Future<void> removeAccount(String email) async {
    await _storage.removeAccount(email);
    _accounts.removeWhere((a) => a.email == email);
    notifyListeners();
  }

  /// Sets this account's nickname — shown everywhere in place of its Google
  /// account name/email (search results, chips, The Stacks). Pass `null` (or
  /// an empty/whitespace string) to revert to the Google name.
  Future<void> renameAccount(String email, String? label) async {
    final trimmed = label?.trim();
    final normalized = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    await _storage.setCustomLabel(email, normalized);
    final index = _accounts.indexWhere((a) => a.email == email);
    if (index == -1) return;
    final a = _accounts[index];
    _accounts[index] = LinkedAccount(
      email: a.email,
      googleName: a.googleName,
      customLabel: normalized,
      inkIndex: a.inkIndex,
      linkedAt: a.linkedAt,
      refreshFailed: a.refreshFailed,
    );
    notifyListeners();
  }

  /// Returns a valid access token for [email], refreshing it first. On
  /// invalid_grant (the account's ~7-day testing-mode window ran out) this
  /// flags the account and rethrows so callers (search aggregation) can
  /// skip that account instead of failing the whole search.
  Future<String> getValidAccessToken(String email) async {
    final refreshToken = await _storage.getRefreshToken(email);
    if (refreshToken == null) {
      throw ReconnectRequiredException(email);
    }
    try {
      return await _oauth.refreshAccessToken(
        email: email,
        refreshToken: refreshToken,
      );
    } on ReconnectRequiredException {
      await _storage.markRefreshFailed(email);
      final index = _accounts.indexWhere((a) => a.email == email);
      if (index != -1) {
        final a = _accounts[index];
        _accounts[index] = LinkedAccount(
          email: a.email,
          googleName: a.googleName,
          customLabel: a.customLabel,
          inkIndex: a.inkIndex,
          linkedAt: a.linkedAt,
          refreshFailed: true,
        );
        notifyListeners();
      }
      rethrow;
    }
  }
}
