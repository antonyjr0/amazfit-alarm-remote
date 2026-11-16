import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_alarm_remote/protocol.dart';

class FakeTransport implements AlarmTransport {
  int calls = 0;
  final Completer<Envelope> result = Completer<Envelope>();
  @override
  Future<Envelope> execute(Envelope r) {
    calls++;
    return result.future;
  }
}

void main() {
  Envelope req([
    String id = 'req',
    String alarm = 'alarm',
    int time = 100000,
  ]) => Envelope('ALARM_DISMISS', id, alarm, time, {});
  test(
    'Envelope rejects invalid sizes, identifiers, payloads and confirmations',
    () {
      expect(Envelope.parse(jsonEncode(req().toJson())), isNotNull);
      for (final pair in <String, dynamic>{
        'version': 2,
        'requestId': 'bad id',
        'alarmId': null,
        'timestamp': -1,
        'payload': [],
        'type': 'UNKNOWN',
      }.entries) {
        expect(
          Envelope.parse(jsonEncode({...req().toJson(), pair.key: pair.value})),
          isNull,
        );
      }
      expect(
        Envelope.parse(
          jsonEncode({
            ...req().toJson(),
            'payload': {'minutes': 5},
          }),
        ),
        isNull,
      );
      expect(
        Envelope.parse(
          jsonEncode({
            ...req().toJson(),
            'type': 'ALARM_DISMISSED',
            'payload': {'phase': 'SENT'},
          }),
        ),
        isNull,
      );
      expect(Envelope.parse(' ' * 2049), isNull);
      expect(Envelope.parse('{'), isNull);
      final missingAlarmId = Envelope('CONNECTION_STATUS', 'r', null, 0, {
        'connected': false,
        'androidAvailable': false,
      }).toJson()..remove('alarmId');
      expect(Envelope.parse(jsonEncode(missingAlarmId)), isNull);
      expect(
        Envelope.parse(
          jsonEncode(
            Envelope('ERROR', 'r', null, 0, {'code': 'UNVERIFIED'}).toJson(),
          ),
        ),
        isNull,
      );
    },
  );
  test('Not configured never reports executed', () async {
    final s = CommandSession(NotConfiguredTransport())..activeAlarm = 'alarm';
    final r = await s.execute(req(), 100000);
    expect(r.type, 'ERROR');
    expect(r.payload['code'], 'NOT_CONFIGURED');
    expect(r.requestId, 'req');
    expect(r.alarmId, 'alarm');
  });
  test(
    'Duplicate pending command invokes transport once and rejects reused ID',
    () async {
      final t = FakeTransport();
      final session = CommandSession(t)..activeAlarm = 'alarm';
      final a = session.execute(req(), 100000),
          b = session.execute(req(), 100000);
      await Future<void>.delayed(Duration.zero);
      expect(t.calls, 1);
      final altered = Envelope('ALARM_SNOOZE', 'req', 'alarm', 100000, {});
      expect(
        (await session.execute(altered, 100000)).payload['code'],
        'INVALID_RESPONSE',
      );
      t.result.complete(
        Envelope('ALARM_DISMISSED', 'req', 'alarm', 100001, {
          'phase': 'EXECUTED',
        }),
      );
      expect((await a).type, 'ALARM_DISMISSED');
      expect((await b).type, 'ALARM_DISMISSED');
    },
  );
  test('Expired, future and ended commands do not execute', () async {
    final t = FakeTransport();
    final s = CommandSession(t)..activeAlarm = 'alarm';
    expect((await s.execute(req(), 110001)).payload['code'], 'TIMEOUT');
    expect(
      (await s.execute(req('future', 'alarm', 105001), 100000)).payload['code'],
      'TIMEOUT',
    );
    s.disconnect();
    expect((await s.execute(req(), 100000)).payload['code'], 'ALARM_ENDED');
    expect(t.calls, 0);
  });
  test('Timeout and late reply cannot confirm success', () async {
    final t = FakeTransport();
    final s = CommandSession(t, timeout: const Duration(milliseconds: 1))
      ..activeAlarm = 'alarm';
    expect((await s.execute(req(), 100000)).payload['code'], 'TIMEOUT');
    t.result.complete(
      Envelope('ALARM_DISMISSED', 'req', 'alarm', 100001, {
        'phase': 'EXECUTED',
      }),
    );
    expect((await s.execute(req(), 100000)).payload['code'], 'TIMEOUT');
  });
  test('Disconnect and new occurrence invalidate pending response', () async {
    final t = FakeTransport();
    final s = CommandSession(t)..activeAlarm = 'alarm';
    final pending = s.execute(req(), 100000);
    s.disconnect();
    s.activeAlarm = 'next';
    t.result.complete(
      Envelope('ALARM_DISMISSED', 'req', 'alarm', 100001, {
        'phase': 'EXECUTED',
      }),
    );
    expect((await pending).payload['code'], 'ALARM_ENDED');
  });
  test('Wrong command completion and correlation are rejected', () async {
    for (final reply in [
      Envelope('ALARM_SNOOZED', 'req', 'alarm', 100001, {'phase': 'EXECUTED'}),
      Envelope('ALARM_DISMISSED', 'other', 'alarm', 100001, {
        'phase': 'EXECUTED',
      }),
    ]) {
      final t = FakeTransport();
      final s = CommandSession(t)..activeAlarm = 'alarm';
      t.result.complete(reply);
      expect(
        (await s.execute(req(), 100000)).payload['code'],
        'INVALID_RESPONSE',
      );
    }
  });
}
