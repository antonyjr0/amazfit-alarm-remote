import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_alarm_remote/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const method = MethodChannel('alarm_remote/native');
  const events = MethodChannel('alarm_remote/events');
  testWidgets('ambiguous notifications disable local buttons', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final fonts = Platform.environment['FONT_DIR'];
    if (fonts != null) {
      await t.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('$fonts/Roboto-Regular.ttf').readAsBytesSync(),
              ),
            ),
          );
        await loader.load();
      });
    }
    var ambiguous = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(method, (c) async {
          if (c.method == 'apps') return [];
          return {
            'permission': true,
            'connected': true,
            'package': 'clock.test',
            'logs': [],
            'alarms': [
              {
                'id': 'phone-example',
                'state': 'UNKNOWN',
                'evidence': 'category=alarm; suoneria non confermata',
              },
              if (ambiguous)
                {
                  'id': 'phone-second',
                  'state': 'UNKNOWN',
                  'evidence': 'category=alarm',
                },
            ],
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(events, (_) async => null);
    final boundary = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(key: boundary, child: const AlarmRemoteApp()),
    );
    await t.pumpAndSettle();
    Future<void> shot(String name) async {
      final dir = Platform.environment['SCREENSHOT_DIR'];
      if (dir == null) return;
      final b =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await t.runAsync(() async {
        final image = await b.toImage(pixelRatio: 1);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await shot('flutter-link-start');
    await t.runAsync(() async {
      await t.tap(find.text('Avvia collegamento di prova'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await t.pump();
    await shot('flutter-link-session');
    await t.scrollUntilVisible(
      find.text('Abilita comandi dal watch'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('Abilita comandi dal watch'));
    await t.pumpAndSettle();
    await shot('flutter-remote-confirm');
    await t.tap(find.text('Annulla'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Chiudi collegamento'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.runAsync(() async {
      await t.tap(find.text('Chiudi collegamento'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await t.pump();
    await t.tap(find.text('Test locale'));
    await t.pumpAndSettle();
    await t.tap(find.text('Spegni'));
    await t.pumpAndSettle();
    await shot('flutter-confirm-local');
    await t.tap(find.text('Annulla'));
    await t.pumpAndSettle();
    ambiguous = true;
    await t.tap(find.byIcon(Icons.refresh));
    await t.pumpAndSettle();
    for (final b in t.widgetList<FilledButton>(
      find.widgetWithText(FilledButton, 'Spegni'),
    )) {
      expect(b.onPressed, null);
    }
    await shot('flutter-ambiguous');
    await t.pumpWidget(const SizedBox());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(method, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(events, null);
  });
}
