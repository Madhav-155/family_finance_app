import 'package:family_finance_app/shared/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySettingsStorage implements AppSettingsStorage {
  AppSettingsState? value;

  @override
  Future<AppSettingsState?> read() async => value;

  @override
  Future<void> write(AppSettingsState value) async => this.value = value;
}

void main() {
  test('appearance and language settings restore and persist', () async {
    final storage = _MemorySettingsStorage()
      ..value = const AppSettingsState(
        themeMode: ThemeMode.dark,
        locale: Locale('te'),
        largeText: true,
      );
    final container = ProviderContainer(
      overrides: [appSettingsStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    container.read(appSettingsProvider);
    await Future<void>.delayed(Duration.zero);
    var state = container.read(appSettingsProvider);
    expect(state.themeMode, ThemeMode.dark);
    expect(state.locale.languageCode, 'te');
    expect(state.largeText, isTrue);

    final controller = container.read(appSettingsProvider.notifier);
    controller.toggleDarkMode(false);
    controller.setLocale('en');
    controller.toggleLargeText(false);
    await Future<void>.delayed(Duration.zero);

    state = storage.value!;
    expect(state.themeMode, ThemeMode.light);
    expect(state.locale.languageCode, 'en');
    expect(state.largeText, isFalse);
  });
}
