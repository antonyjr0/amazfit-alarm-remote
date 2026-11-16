import 'package:flutter/services.dart';
import 'protocol.dart';

enum AlarmCommand { dismiss, snooze }

enum SettingsTarget { notifications, app }

class ClockApp {
  final String package, label;
  ClockApp(Map m)
    : package = m['package'] as String,
      label = m['label'] as String;
}

class AlarmCandidate {
  final String id, state, evidence;
  final bool consumed;
  AlarmCandidate(Map m)
    : id = m['id'] as String,
      state = m['state'] as String,
      evidence = m['evidence'] as String,
      consumed = m['consumed'] == true;
}

class DiagnosticEvent {
  final int time;
  final String event;
  DiagnosticEvent(Map m)
    : time = m['time'] as int,
      event = m['event'] as String;
}

class NativeSnapshot {
  final bool permission, connected;
  final String package, lastCommand;
  final List<AlarmCandidate> alarms;
  final List<DiagnosticEvent> logs;
  NativeSnapshot(Map m)
    : permission = m['permission'] == true,
      connected = m['connected'] == true,
      package = m['package'] as String? ?? '',
      lastCommand = m['lastCommand'] as String? ?? 'Nessuno',
      alarms = List.unmodifiable(
        (m['alarms'] as List? ?? []).map((a) => AlarmCandidate(a as Map)),
      ),
      logs = List.unmodifiable(
        (m['logs'] as List? ?? []).map((l) => DiagnosticEvent(l as Map)),
      );
}

/// The only Flutter component aware of wire channel names and untyped codecs.
class PlatformBridge {
  static const _method = MethodChannel('alarm_remote/native');
  static const _events = EventChannel('alarm_remote/events');
  Stream<NativeSnapshot> get events =>
      _events.receiveBroadcastStream().map((e) => NativeSnapshot(e as Map));
  Future<NativeSnapshot> snapshot() async =>
      NativeSnapshot((await _method.invokeMapMethod('snapshot'))!);
  Future<Map<String, dynamic>> wireSnapshot() async =>
      Map<String, dynamic>.from((await _method.invokeMapMethod('snapshot'))!);
  Future<String> remoteCommand(Envelope r) async =>
      (await _method.invokeMethod<String>('remoteCommand', {
        'command': r.type == 'ALARM_DISMISS' ? 'DISMISS' : 'SNOOZE',
        'alarmId': r.alarmId,
        'requestId': r.requestId,
        'timestamp': r.timestamp,
      })) ??
      'FAILED';
  Future<List<ClockApp>> apps() async =>
      ((await _method.invokeListMethod('apps')) ?? [])
          .map((a) => ClockApp(a as Map))
          .toList();
  Future<void> select(String package) =>
      _method.invokeMethod('select', {'package': package});
  Future<void> settings(SettingsTarget target) =>
      _method.invokeMethod('settings', {'target': target.name});
  Future<void> clearLogs() => _method.invokeMethod('clearLogs');
  Future<String> command(AlarmCommand command, String alarmId) async =>
      (await _method.invokeMethod<String>('command', {
        'command': command.name.toUpperCase(),
        'alarmId': alarmId,
      })) ??
      'Esito sconosciuto';
}
