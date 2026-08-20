import 'package:flutter/material.dart';

/// Type roles: Fraunces carries the wordmark and headlines, used sparingly.
/// IBM Plex Sans is every interface label. IBM Plex Mono is every piece of
/// metadata — timestamps, emails, file extensions, account tags — so the
/// interface always visually distinguishes "what a human wrote" from
/// "what the system recorded."
class AppText {
  AppText._();

  static TextStyle display({
    required Color color,
    double size = 28,
    FontWeight weight = FontWeight.w600,
    bool italic = false,
  }) {
    return TextStyle(
      fontFamily: 'Fraunces',
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      fontSize: size,
      color: color,
      height: 1.05,
      letterSpacing: -0.2,
    );
  }

  static TextStyle body({
    required Color color,
    double size = 14,
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      fontSize: size,
      color: color,
      height: 1.4,
    );
  }

  static TextStyle mono({
    required Color color,
    double size = 11,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: 'IBM Plex Mono',
      fontWeight: weight,
      fontSize: size,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.4,
    );
  }

  static TextStyle eyebrow(Color color) => mono(
        color: color,
        size: 10.5,
        weight: FontWeight.w500,
        letterSpacing: 1.4,
      );
}
