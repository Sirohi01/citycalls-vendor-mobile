import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _storageKey = 'citycalls_theme_mode';
  final FlutterSecureStorage _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.system) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      state = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _storageKey, value: mode.name);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(const FlutterSecureStorage()),
);
