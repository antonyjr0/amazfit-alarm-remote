// Test process only. No Android capability is implied by this fixture.
import 'dart:io';
import '../android_alarm_remote/lib/loopback_link.dart';
Future<void> main() async {
  var calls = 0;
  final link = LoopbackLink(snapshot: () async => {
    'permission': true, 'connected': true,
    'alarms': [{'id': 'fixture-alarm', 'state': 'UNKNOWN', 'consumed': false}],
  }, command: (_) async { stdout.writeln('native-stub:${++calls}'); return 'UNVERIFIED'; }, changed: () {});
  await link.start(); link.arm('fixture-alarm');
  // Private pipe to the test parent. The runner never prints this credential.
  stdout.writeln(link.pairing);
  await stdin.first; await link.stop();
}
