import 'dart:convert';

import 'package:flutter/material.dart';

/// What the user has chosen, kept between launches. Anything missing or damaged reads as the
/// default, so a bad file never stops the app.
@immutable
class AppSettings {
  const AppSettings({
    this.welcomed = false,
    this.checkForUpdates = true,
    this.language,
    this.lastUpdateCheck,
    this.theme = 'system',
    this.showPreviews = true,
    this.resultsFolder,
    this.learnOrder = true,
    this.uses = const {},
    this.triggerKey = 'shift',
    this.whatsNewSeen,
  });

  /// Whether the first-launch guide has been seen, or skipped.
  final bool welcomed;

  /// Whether a copy downloaded from the website asks once a day if there's a newer version. The only
  /// thing the app ever fetches, and it can be turned off.
  final bool checkForUpdates;

  /// `en` or `hi`, or null to follow the device.
  final String? language;
  final DateTime? lastUpdateCheck;

  /// `system`, `light` or `dark`.
  final String theme;

  /// Whether files and results show a small picture of their first page.
  final bool showPreviews;

  /// Where results go on a desktop, or null for beside each original.
  final String? resultsFolder;

  /// Whether the menus put the actions used most in the first slots.
  final bool learnOrder;

  /// How often each action has been used, by its id. Kept on this device only, with the settings.
  final Map<String, int> uses;

  /// The key held while dragging that opens the menu over other apps: "shift" or "control".
  final String triggerKey;

  /// The version whose What's new has been announced, so each update says so once.
  final String? whatsNewSeen;

  static const triggerKeys = {'shift', 'control'};

  /// The most actions [uses] remembers, so the file stays small whatever happens.
  static const mostUses = 200;

  AppSettings copyWith({
    bool? welcomed,
    bool? checkForUpdates,
    String? Function()? language,
    DateTime? lastUpdateCheck,
    String? theme,
    bool? showPreviews,
    String? Function()? resultsFolder,
    bool? learnOrder,
    Map<String, int>? uses,
    String? triggerKey,
    String? whatsNewSeen,
  }) {
    return AppSettings(
      welcomed: welcomed ?? this.welcomed,
      checkForUpdates: checkForUpdates ?? this.checkForUpdates,
      language: language == null ? this.language : language(),
      lastUpdateCheck: lastUpdateCheck ?? this.lastUpdateCheck,
      theme: theme ?? this.theme,
      showPreviews: showPreviews ?? this.showPreviews,
      resultsFolder: resultsFolder == null ? this.resultsFolder : resultsFolder(),
      learnOrder: learnOrder ?? this.learnOrder,
      uses: uses ?? this.uses,
      triggerKey: triggerKey ?? this.triggerKey,
      whatsNewSeen: whatsNewSeen ?? this.whatsNewSeen,
    );
  }

  /// These settings with one more use of [actionId].
  AppSettings usedOnce(String actionId) {
    final counted = {...uses, actionId: (uses[actionId] ?? 0) + 1};
    if (counted.length > mostUses) return this;
    return copyWith(uses: counted);
  }

  static const languages = {'en', 'hi'};
  static const themes = {'system', 'light', 'dark'};

  static AppSettings decode(String? text) {
    if (text == null) return const AppSettings();
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return const AppSettings();
    }
    if (json is! Map) return const AppSettings();
    final language = json['language'];
    final checked = json['lastUpdateCheck'];
    final theme = json['theme'];
    final folder = json['resultsFolder'];
    final uses = json['uses'];
    final trigger = json['triggerKey'];
    final seen = json['whatsNewSeen'];
    return AppSettings(
      welcomed: json['welcomed'] == true,
      checkForUpdates: json['checkForUpdates'] != false,
      language: language is String && languages.contains(language) ? language : null,
      lastUpdateCheck: checked is String ? DateTime.tryParse(checked) : null,
      theme: theme is String && themes.contains(theme) ? theme : 'system',
      showPreviews: json['showPreviews'] != false,
      resultsFolder: folder is String && folder.isNotEmpty ? folder : null,
      learnOrder: json['learnOrder'] != false,
      uses: uses is Map
          ? {
              for (final MapEntry(:key, :value) in uses.entries.take(mostUses))
                if (key is String && value is int && value > 0) key: value,
            }
          : const {},
      triggerKey: trigger is String && triggerKeys.contains(trigger) ? trigger : 'shift',
      whatsNewSeen: seen is String ? seen : null,
    );
  }

  String encode() => jsonEncode({
    'welcomed': welcomed,
    'checkForUpdates': checkForUpdates,
    'language': ?language,
    if (lastUpdateCheck != null) 'lastUpdateCheck': lastUpdateCheck!.toUtc().toIso8601String(),
    'theme': theme,
    'showPreviews': showPreviews,
    'resultsFolder': ?resultsFolder,
    'learnOrder': learnOrder,
    if (uses.isNotEmpty) 'uses': uses,
    'triggerKey': triggerKey,
    'whatsNewSeen': ?whatsNewSeen,
  });

  Locale? get locale => language == null ? null : Locale(language!);

  ThemeMode get themeMode => switch (theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

/// The settings, saved whenever they change. Failing to save never gets in the way.
class SettingsStore extends ValueNotifier<AppSettings> {
  SettingsStore(super.value, {required this.write});

  final Future<void> Function(String text) write;

  static Future<SettingsStore> load({
    required Future<String?> Function() read,
    required Future<void> Function(String text) write,
  }) async {
    AppSettings settings;
    try {
      settings = AppSettings.decode(await read());
    } catch (error) {
      debugPrint('Could not read settings: $error');
      settings = const AppSettings();
    }
    return SettingsStore(settings, write: write);
  }

  Future<void> change(AppSettings Function(AppSettings settings) how) async {
    value = how(value);
    try {
      await write(value.encode());
    } catch (error) {
      debugPrint('Could not write settings: $error');
    }
  }
}

/// Hands the settings to every screen below it.
class SettingsScope extends InheritedNotifier<SettingsStore> {
  const SettingsScope({super.key, required SettingsStore store, required super.child})
    : super(notifier: store);

  /// Null where there are none, as in tests of a single screen.
  static SettingsStore? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
  }

  /// The same, outside building, as when a job starts.
  static SettingsStore? read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<SettingsScope>()?.notifier;
  }
}
