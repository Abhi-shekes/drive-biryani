import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Non-sensitive metadata for one linked account, persisted locally.
/// Refresh tokens are stored separately, keyed by email, so this record
/// never carries anything that would matter if it leaked.
class StoredAccountMeta {
  const StoredAccountMeta({
    required this.email,
    required this.name,
    this.customLabel,
    required this.inkIndex,
    required this.linkedAt,
    required this.refreshFailed,
  });

  final String email;
  final String? name;
  final String? customLabel;
  final int inkIndex;
  final DateTime linkedAt;
  final bool refreshFailed;

  StoredAccountMeta copyWith({
    DateTime? linkedAt,
    bool? refreshFailed,
    String? customLabel,
    bool clearCustomLabel = false,
  }) {
    return StoredAccountMeta(
      email: email,
      name: name,
      customLabel: clearCustomLabel ? null : (customLabel ?? this.customLabel),
      inkIndex: inkIndex,
      linkedAt: linkedAt ?? this.linkedAt,
      refreshFailed: refreshFailed ?? this.refreshFailed,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'name': name,
        'customLabel': customLabel,
        'inkIndex': inkIndex,
        'linkedAt': linkedAt.toIso8601String(),
        'refreshFailed': refreshFailed,
      };

  factory StoredAccountMeta.fromJson(Map<String, dynamic> json) {
    return StoredAccountMeta(
      email: json['email'] as String,
      name: json['name'] as String?,
      customLabel: json['customLabel'] as String?,
      inkIndex: json['inkIndex'] as int,
      linkedAt: DateTime.parse(json['linkedAt'] as String),
      refreshFailed: json['refreshFailed'] as bool? ?? false,
    );
  }
}

/// Wraps flutter_secure_storage (OS keychain/keystore) for everything a
/// linked account needs on-device: its refresh token and its metadata.
/// Nothing here ever syncs off-device.
class AccountStorage {
  const AccountStorage();

  static const _storage = FlutterSecureStorage();
  static const _metaKey = 'linked_accounts_meta';

  String _tokenKey(String email) => 'refresh_token::$email';

  Future<List<StoredAccountMeta>> loadAccounts() async {
    final raw = await _storage.read(key: _metaKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => StoredAccountMeta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAccounts(List<StoredAccountMeta> accounts) async {
    final raw = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _metaKey, value: raw);
  }

  Future<void> upsertAccount(
    StoredAccountMeta meta, {
    required String? refreshToken,
  }) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.email == meta.email);
    accounts.add(meta);
    await _saveAccounts(accounts);
    if (refreshToken != null) {
      await _storage.write(key: _tokenKey(meta.email), value: refreshToken);
    }
  }

  Future<void> markRefreshFailed(String email) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.email == email);
    if (index == -1) return;
    accounts[index] = accounts[index].copyWith(refreshFailed: true);
    await _saveAccounts(accounts);
  }

  /// Sets or clears the user's nickname for [email]. Pass `null` to revert
  /// to showing the Google account name/email.
  Future<void> setCustomLabel(String email, String? label) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((a) => a.email == email);
    if (index == -1) return;
    accounts[index] = accounts[index].copyWith(
      customLabel: label,
      clearCustomLabel: label == null,
    );
    await _saveAccounts(accounts);
  }

  Future<String?> getRefreshToken(String email) {
    return _storage.read(key: _tokenKey(email));
  }

  Future<void> removeAccount(String email) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((a) => a.email == email);
    await _saveAccounts(accounts);
    await _storage.delete(key: _tokenKey(email));
  }
}
