import 'dart:async';
import 'dart:convert';

const types = {
  'ALARM_RINGING',
  'ALARM_STOPPED',
  'ALARM_DISMISS',
  'ALARM_SNOOZE',
  'ALARM_DISMISSED',
  'ALARM_SNOOZED',
  'CONNECTION_STATUS',
  'ERROR',
};
const codes = {
  'DISCONNECTED',
  'PHONE_UNREACHABLE',
  'ANDROID_UNAVAILABLE',
  'TIMEOUT',
  'ALARM_ENDED',
  'UNSUPPORTED',
  'INVALID_RESPONSE',
  'FAILED',
  'NOT_CONFIGURED',
};
bool validId(Object? x) =>
    x is String && RegExp(r'^[a-zA-Z0-9_.:-]{1,128}$').hasMatch(x);

class Envelope {
  final String type, requestId;
  final String? alarmId;
  final int timestamp;
  final Map<String, dynamic> payload;
  Envelope(
    this.type,
    this.requestId,
    this.alarmId,
    this.timestamp,
    this.payload,
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'type': type,
    'requestId': requestId,
    'alarmId': alarmId,
    'timestamp': timestamp,
    'payload': payload,
  };
  static Envelope? parse(String raw) {
    if (raw.length > 2048) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic> ||
          m['version'] != 1 ||
          !types.contains(m['type']) ||
          !validId(m['requestId']) ||
          m['timestamp'] is! int ||
          m['timestamp'] < 0 ||
          m['timestamp'] > 9007199254740991 ||
          m['payload'] is! Map<String, dynamic> ||
          !m.containsKey('alarmId') ||
          (m['alarmId'] != null && !validId(m['alarmId']))) {
        return null;
      }
      final t = m['type'] as String, p = m['payload'] as Map<String, dynamic>;
      if (t.startsWith('ALARM_') && !validId(m['alarmId'])) return null;
      if ({'ALARM_DISMISS', 'ALARM_SNOOZE'}.contains(t) && p.isNotEmpty) {
        return null;
      }
      if ({'ALARM_DISMISSED', 'ALARM_SNOOZED'}.contains(t) &&
          p['phase'] != 'EXECUTED') {
        return null;
      }
      if (t == 'ERROR' && !codes.contains(p['code'])) return null;
      if (t == 'CONNECTION_STATUS' &&
          (p['connected'] is! bool || p['androidAvailable'] is! bool)) {
        return null;
      }
      if (t == 'ALARM_RINGING' &&
          p.containsKey('time') &&
          (p['time'] is! String ||
              !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(p['time']))) {
        return null;
      }
      return Envelope(t, m['requestId'], m['alarmId'], m['timestamp'], p);
    } catch (_) {
      return null;
    }
  }

  Envelope error(String code) => Envelope(
    'ERROR',
    requestId,
    alarmId,
    DateTime.now().millisecondsSinceEpoch,
    {'code': code},
  );
}

abstract interface class AlarmTransport {
  Future<Envelope> execute(Envelope request);
}

class NotConfiguredTransport implements AlarmTransport {
  @override
  Future<Envelope> execute(Envelope request) async =>
      request.error('NOT_CONFIGURED');
}

/// Session guard only: a real adapter must add a persistent command ledger.
class CommandSession {
  final AlarmTransport transport;
  final Duration timeout;
  final Map<String, (String, Future<Envelope>)> _cache = {};
  String? activeAlarm;
  int _generation = 0;
  CommandSession(this.transport, {this.timeout = const Duration(seconds: 8)});
  void disconnect() {
    activeAlarm = null;
    _generation++;
  }

  Future<Envelope> execute(Envelope r, int now) {
    if (Envelope.parse(jsonEncode(r.toJson())) == null ||
        !{'ALARM_DISMISS', 'ALARM_SNOOZE'}.contains(r.type)) {
      return Future.value(r.error('INVALID_RESPONSE'));
    }
    if (now - r.timestamp > 10000 || r.timestamp - now > 5000) {
      return Future.value(r.error('TIMEOUT'));
    }
    if (activeAlarm != r.alarmId) return Future.value(r.error('ALARM_ENDED'));
    final signature = jsonEncode(r.toJson()), old = _cache[r.requestId];
    if (old != null) {
      return signature == old.$1
          ? old.$2
          : Future.value(r.error('INVALID_RESPONSE'));
    }
    if (_cache.length >= 128) return Future.value(r.error('FAILED'));
    final generation = _generation;
    final future = Future.sync(() => transport.execute(r))
        .timeout(timeout, onTimeout: () => r.error('TIMEOUT'))
        .then((a) {
          if (generation != _generation || activeAlarm != r.alarmId) {
            return r.error('ALARM_ENDED');
          }
          final expected = r.type == 'ALARM_DISMISS'
              ? 'ALARM_DISMISSED'
              : 'ALARM_SNOOZED';
          if (Envelope.parse(jsonEncode(a.toJson())) == null ||
              a.requestId != r.requestId ||
              a.alarmId != r.alarmId ||
              (a.type != expected && a.type != 'ERROR')) {
            return r.error('INVALID_RESPONSE');
          }
          return a;
        })
        .catchError((Object _) => r.error('FAILED'));
    _cache[r.requestId] = (signature, future);
    return future;
  }
}
