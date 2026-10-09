import 'package:flutter/material.dart';

class Palette {
  static const night = Color(0xFF1E140D);
  static const panel = Color(0xE62B1B12);
  static const saffron = Color(0xFFE6A23C);
  static const brick = Color(0xFFB5523B);
  static const sand = Color(0xFFF2E6D0);
  static const muted = Color(0x99F2E6D0);

  static final theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: saffron,
      brightness: Brightness.dark,
      primary: saffron,
      secondary: brick,
    ),
  );

  static String clock(int milliseconds) {
    final seconds = (milliseconds / 1000).ceil().clamp(0, 99 * 60);
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class Panel extends StatelessWidget {
  const Panel({required this.child, this.padding = 16, super.key});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33E6A23C)),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}
