import 'package:flutter/material.dart';
import '../models/linked_account.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Connection-health pill. Always one of ok/warn/danger — never brass, so
/// "this needs attention" never gets visually confused with "this is the
/// accent color of the app."
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.daysUntilExpiry});

  final ConnectionStatus status;
  final int? daysUntilExpiry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, label) = switch (status) {
      ConnectionStatus.connected => (c.ok, 'Connected'),
      ConnectionStatus.reconnectSoon => (
          c.warn,
          '${daysUntilExpiry ?? 0} days left',
        ),
      ConnectionStatus.expired => (c.danger, 'Reconnect'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.mono(color: color, size: 11)),
        ],
      ),
    );
  }
}
