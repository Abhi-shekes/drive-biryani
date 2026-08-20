import 'package:flutter/material.dart';

/// Design tokens for DriveBiryani, ported from the "Stacks" UI design plan.
/// One accent (brass), three semantic connection-health colors, and a
/// rotating set of archival "account inks" — nothing else may borrow them.
class AppColors {
  const AppColors._({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.brass,
    required this.ok,
    required this.warn,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color brass;
  final Color ok;
  final Color warn;
  final Color danger;

  static const dark = AppColors._(
    bg: Color(0xFF171D19),
    surface: Color(0xFF1F2621),
    surface2: Color(0xFF262E28),
    text: Color(0xFFF1EEE4),
    textMuted: Color(0xFF93A093),
    border: Color(0x17F1EEE4),
    brass: Color(0xFFD2A24C),
    ok: Color(0xFF6FA084),
    warn: Color(0xFFD3874F),
    danger: Color(0xFFC15D53),
  );

  static const light = AppColors._(
    bg: Color(0xFFF7F4EC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0EDE2),
    text: Color(0xFF1B211D),
    textMuted: Color(0xFF6B7568),
    border: Color(0x1A1B211D),
    brass: Color(0xFFA6752A),
    ok: Color(0xFF3E7A5C),
    warn: Color(0xFFB3652C),
    danger: Color(0xFFA6433A),
  );

  /// Archival inks assigned round-robin to linked accounts. Never reused
  /// for anything else — an account's ink is its identity everywhere:
  /// the search results flag, the avatar ring, the Stacks row.
  static const accountInks = <Color>[
    Color(0xFF2E8A8F), // petrol teal
    Color(0xFF8256A6), // dusty plum
    Color(0xFF4A6FA6), // slate blue
    Color(0xFF8A4A5E), // rose mauve
    Color(0xFF4A4A8A), // deep indigo
    Color(0xFF5C6B3E), // olive moss
  ];

  static Color inkForIndex(int i) => accountInks[i % accountInks.length];
}
