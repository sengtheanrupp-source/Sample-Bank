import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// Romdoul Bank palette - deep Mekong teal, temple gold, palm-leaf cream.
class RB {
  static const night = Color(0xFF071C29);
  static const navy = Color(0xFF0B2A3C);
  static const teal = Color(0xFF0F4C5C);
  static const aqua = Color(0xFF22C1B6);
  static const gold = Color(0xFFE9B949);
  static const goldDeep = Color(0xFFC08A17);
  static const cream = Color(0xFFFBF6EC);
  static const sand = Color(0xFFF1E7D3);
  static const ink = Color(0xFF1C2430);
  static const muted = Color(0xFF6B7380);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const warn = Color(0xFFD97706);

  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [night, teal],
  );

  static const payGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E3B4E), night],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RB.teal,
    primary: RB.teal,
    secondary: RB.gold,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: RB.cream,
    splashFactory: InkSparkle.splashFactory,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: RB.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: RB.ink),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}
