import 'package:material_ui/material_ui.dart';

abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25833E)),
    scaffoldBackgroundColor: const Color(0xFFF3F7F4),
  );
}
