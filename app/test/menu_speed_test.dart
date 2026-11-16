import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftdrop/app_settings.dart';
import 'package:shiftdrop/menu_speed.dart';
import 'package:shiftdrop/settings_screen.dart';
import 'package:shiftdrop/shift_drag.dart';
import 'package:shiftdrop/words.dart';

void main() {
  group('a timing from the native menu', () {
    test('is read with all its parts', () {
      final timing = MenuTiming.fromWire({'wait': 20.5, 'find': 3, 'ask': 30, 'draw': 6.5})!;
      expect(timing.total, 60);
      expect(timing.toString(), 'wait 21 + find 3 + ask 30 + draw 7 = 60 ms');
    });

    test('anything odd is dropped rather than shown', () {
      expect(MenuTiming.fromWire(null), isNull);
      expect(MenuTiming.fromWire({'wait': 1, 'ask': 2, 'draw': 3}), isNull);
      expect(MenuTiming.fromWire({'wait': -1, 'find': 0, 'ask': 2, 'draw': 3}), isNull);
      expect(MenuTiming.fromWire({'wait': 'x', 'find': 0, 'ask': 2, 'draw': 3}), isNull);
      expect(MenuTiming.fromWire({'wait': double.nan, 'find': 0, 'ask': 2, 'draw': 3}), isNull);
    });
  });

  group('the speed so far', () {
    test('nothing before any menu has opened', () => expect(MenuSpeed().summary, isNull));

    test('the usual time is the middle one, so one slow drag doesn\'t hide the rest', () {
      final speed = MenuSpeed();
      for (final ms in [40, 200, 50, 45, 60]) {
        speed.add(MenuTiming(ask: ms.toDouble()));
      }
      expect(speed.summary, (usual: 50, slowest: 200, count: 5));
      speed.add(const MenuTiming(ask: 55));
      expect(speed.summary!.usual, 53);
    });

    test('only the last few are kept', () {
      final speed = MenuSpeed();
      for (var i = 0; i < MenuSpeed.kept + 10; i++) {
        speed.add(MenuTiming(ask: i.toDouble()));
      }
      expect(speed.value, hasLength(MenuSpeed.kept));
      expect(speed.value.first.ask, 10);
    });
  });

  testWidgets('Settings says how fast the menu opens, once it has', (tester) async {
    final store = SettingsStore(const AppSettings(), write: (_) async {});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: Words.localizationsDelegates,
        home: Scaffold(body: TriggerKeyChoice(settings: store)),
      ),
    );
    expect(find.text('Drag a file with Shift held to measure how fast the menu opens.'), findsOne);
    MenuSpeed.instance
      ..add(const MenuTiming(wait: 20, ask: 30, draw: 10))
      ..add(const MenuTiming(wait: 30, ask: 40, draw: 10));
    addTearDown(() => MenuSpeed.instance.value = const []);
    await tester.pump();
    expect(find.text('The menu opened in 70 ms, 80 ms at most, over the last 2 drags.'), findsOne);
  });

  test('the native menu\'s timings arrive over the channel', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final stop = listenForShiftDrag(
      menuFor: (paths, mode) async => const [],
      sizeOf: (action, paths) async => null,
      chosen: (action, paths, options) {},
    );
    addTearDown(stop);
    addTearDown(() => MenuSpeed.instance.value = const []);
    const codec = StandardMethodCodec();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      shiftDragChannel.name,
      codec.encodeMethodCall(
        const MethodCall('menuTiming', {'wait': 10.0, 'find': 0.0, 'ask': 25.0, 'draw': 8.0}),
      ),
      (_) {},
    );
    expect(MenuSpeed.instance.summary, (usual: 43, slowest: 43, count: 1));
  }, skip: Platform.isMacOS || Platform.isWindows ? null : 'Only desktops have the menu');
}
