import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ConnectionStatus { connected, reconnectSoon, expired }

/// One linked Google account. Status is derived, not stored: Google doesn't
/// tell us up front when a Testing-mode refresh token will die, only that it
/// happens ~7 days after it was issued (or immediately, if a real refresh
/// attempt already failed with invalid_grant). [inkIndex] is fixed at link
/// time so an account keeps its color for as long as it stays linked.
class LinkedAccount {
  const LinkedAccount({
    required this.email,
    required this.googleName,
    this.customLabel,
    required this.inkIndex,
    required this.linkedAt,
    this.refreshFailed = false,
  });

  final String email;
  final String googleName;
  final String? customLabel;
  final int inkIndex;
  final DateTime linkedAt;
  final bool refreshFailed;

  /// What's shown everywhere (search results, chips, avatars): the user's
  /// own nickname for this account when they've set one, else Google's
  /// account name, else the raw email.
  String get label {
    if (customLabel != null && customLabel!.trim().isNotEmpty) {
      return customLabel!;
    }
    return googleName.isNotEmpty ? googleName : email;
  }

  static const _expiryWindow = Duration(days: 7);
  static const _warnWindow = Duration(days: 5);

  Duration get _elapsed => DateTime.now().difference(linkedAt);

  ConnectionStatus get status {
    if (refreshFailed || _elapsed >= _expiryWindow) {
      return ConnectionStatus.expired;
    }
    if (_elapsed >= _warnWindow) return ConnectionStatus.reconnectSoon;
    return ConnectionStatus.connected;
  }

  int? get daysUntilExpiry {
    final remaining = _expiryWindow.inDays - _elapsed.inDays;
    return remaining > 0 ? remaining : null;
  }

  Color get ink => AppColors.inkForIndex(inkIndex);

  String get initial => email.isNotEmpty ? email[0].toUpperCase() : '?';
}
