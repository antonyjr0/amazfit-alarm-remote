import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_alarm_remote/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Shows unavailable bridge and requires explicit local test confirmation',
    (tester) async {
      const method = MethodChannel('alarm_remote/native');
      final commands = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(method, (call) async {
            if (call.method == 'apps') return [];
            if (call.method == 'command') {
              commands.add(call);
              return 'UNVERIFIED';
            }
            return {
              'permission': true,
              'connected': true,
              'package': 'clock.test',
              'alarms': [
                {'id': 'a', 'state': 'UNKNOWN', 'evidence': 'category=alarm'},
              ],
              'logs': [],
            };
          });
      const events = MethodChannel('alarm_remote/events');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(events, (_) async => null);
      await tester.pumpWidget(const AlarmRemoteApp());
      await tester.pumpAndSettle();
      expect(
        find.text('Collegamento orologio non configurato'),
        findsOneWidget,
      );
      await tester.tap(find.text('Test locale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spegni'));
      await tester.pumpAndSettle();
      expect(commands, isEmpty);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(commands, isEmpty);
      await tester.tap(find.text('Posticipa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confermo: sta suonando'));
      await tester.pumpAndSettle();
      expect(commands.single.arguments['command'], 'SNOOZE');
      expect(find.text('UNVERIFIED'), findsOneWidget);
      await tester.pumpWidget(const AlarmRemoteApp());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(method, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(events, null);
    },
  );
}
