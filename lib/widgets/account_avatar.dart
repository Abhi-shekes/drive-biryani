import 'package:flutter/material.dart';
import '../models/linked_account.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Small circular avatar ringed in the account's ink. The ring is the same
/// device used as the "flag" on result rows — this is the identity marker
/// worn small.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.account,
    this.size = 28,
    this.showStatusDot = true,
  });

  final LinkedAccount account;
  final double size;
  final bool showStatusDot;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dotColor = switch (account.status) {
      ConnectionStatus.connected => c.ok,
      ConnectionStatus.reconnectSoon => c.warn,
      ConnectionStatus.expired => c.danger,
    };
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface2,
              border: Border.all(color: account.ink, width: 1.6),
            ),
            alignment: Alignment.center,
            child: Text(
              account.initial,
              style: AppText.mono(
                color: c.textMuted,
                size: size * 0.36,
                weight: FontWeight.w500,
              ),
            ),
          ),
          if (showStatusDot)
            Positioned(
              bottom: -1,
              right: -1,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(color: c.bg, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
