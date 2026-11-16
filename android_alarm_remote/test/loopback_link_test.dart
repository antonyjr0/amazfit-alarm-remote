import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_alarm_remote/loopback_link.dart';
import 'package:android_alarm_remote/protocol.dart';

void main() {
  late LoopbackLink link;
  late HttpClient client;
  var commands = 0;
  Map<String, dynamic> state = {};
  Envelope req(String type, [String id = 'r', String? alarm]) => Envelope(
    type,
    id,
    alarm,
    DateTime.now().millisecondsSinceEpoch,
    type == 'CONNECTION_STATUS'
        ? {'connected': true, 'androidAvailable': false}
        : {},
  );
  setUp(() async {
    commands = 0;
    state = {
      'permission': true,
      'connected': true,
      'alarms': [
        {'id': 'a', 'state': 'UNKNOWN', 'consumed': false},
      ],
    };
    link = LoopbackLink(
      snapshot: () async => state,
      command: (_) async {
        commands++;
        return 'UNVERIFIED · sent';
      },
      changed: () {},
    );
    client = HttpClient();
    await link.start();
  });
  tearDown(() async {
    client.close(force: true);
    await link.stop();
  });
  Future<(int, dynamic)> post(
    String path,
    Object body, {
    String? auth,
    String? origin,
  }) async {
    final pair = link.pairing!.split(':');
    final h = await client.postUrl(
      Uri.parse('http://127.0.0.1:${pair[0]}$path'),
    );
    h.headers.contentType = ContentType.json;
    final raw = body is String ? body : jsonEncode(body);
    h.headers.set(
      'x-alarm-mac',
      auth ??
          Hmac(
            sha256,
            utf8.encode(pair[1]),
          ).convert(utf8.encode('$path\n$raw')).toString(),
    );
    if (origin != null) h.headers.set('origin', origin);
    h.write(raw);
    final response = await h.close();
    final text = await utf8.decoder.bind(response).join();
    return (
      response.statusCode,
      text.isEmpty
          ? null
          : (response.statusCode == 200
                ? jsonDecode(jsonDecode(text)['body'] as String)
                : jsonDecode(text)),
    );
  }

  test(
    'real HTTP loopback ping is correlated, candidate is explicitly not ringing',
    () async {
      final r = req('CONNECTION_STATUS');
      final result = await post('/v1/status', r.toJson());
      expect(result.$1, 200);
      final status = Envelope.parse(jsonEncode(result.$2))!;
      expect(status.requestId, r.requestId);
      expect(status.type, 'CONNECTION_STATUS');
      expect(status.payload['candidate'], {'id': 'a', 'armed': false});
      expect(commands, 0);
    },
  );
  test(
    'wrong/missing auth, browser origin, oversized and malformed fail closed',
    () async {
      expect((await post('/v1/status', {}, auth: 'wrong')).$1, 403);
      expect(
        (await post(
          '/v1/status',
          req('CONNECTION_STATUS').toJson(),
          auth: '0' * 64,
        )).$1,
        403,
      );
      expect(
        (await post('/v1/status', {}, origin: 'http://localhost')).$1,
        403,
      );
      expect((await post('/v1/status', 'x' * 2049)).$1, 413);
      expect((await post('/v1/status', '{')).$1, 400);
      expect(commands, 0);
    },
  );
  test(
    'unarmed refuses; armed exactly once, duplicates do not replay',
    () async {
      expect(
        (await post(
          '/v1/command',
          req('ALARM_DISMISS', 'unarmed', 'a').toJson(),
        )).$2['type'],
        'ERROR',
      );
      link.arm('a');
      final r = req('ALARM_DISMISS', 'armed', 'a');
      final results = await Future.wait([
        post('/v1/command', r.toJson()),
        post('/v1/command', r.toJson()),
      ]);
      expect(results.every((r) => r.$2['type'] == 'ALARM_COMMAND_SENT'), true);
      expect(results[0].$2['payload']['phase'], 'SENT_UNVERIFIED');
      expect(commands, 1);
      expect(
        (await post(
          '/v1/command',
          req('ALARM_SNOOZE', 'armed', 'a').toJson(),
        )).$2['payload']['code'],
        'INVALID_RESPONSE',
      );
    },
  );
  test(
    'ambiguous, removed, disconnected and stale requests do not invoke native',
    () async {
      link.arm('a');
      state['alarms'] = [
        {'id': 'a', 'state': 'UNKNOWN'},
        {'id': 'b', 'state': 'UNKNOWN'},
      ];
      expect(
        (await post(
          '/v1/command',
          req('ALARM_DISMISS', 'ambiguous', 'a').toJson(),
        )).$2['type'],
        'ERROR',
      );
      state['alarms'] = [];
      link.arm('a');
      expect(
        (await post(
          '/v1/command',
          req('ALARM_DISMISS', 'removed', 'a').toJson(),
        )).$2['type'],
        'ERROR',
      );
      final stale = req('ALARM_DISMISS', 'stale', 'a').toJson();
      stale['timestamp'] = 0;
      expect(
        (await post('/v1/command', stale)).$2['payload']['code'],
        'TIMEOUT',
      );
      expect(commands, 0);
    },
  );
  test('disarm and stopped sessions invalidate old credentials', () async {
    link.arm('a');
    link.disarm();
    expect(link.armed('a'), false);
    final old = link.pairing;
    await link.stop();
    expect(link.pairing, null);
    await link.start();
    expect(link.pairing, isNot(old));
    expect(link.armed('a'), false);
    expect(
      (await post(
        '/v1/status',
        req('CONNECTION_STATUS').toJson(),
        auth: 'Bearer ${old!.split(':')[1]}',
      )).$1,
      403,
    );
  });
}
