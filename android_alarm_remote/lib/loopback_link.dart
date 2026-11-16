import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'protocol.dart';
import 'package:crypto/crypto.dart';

/// Session-only loopback adapter. No LAN bind, CORS, background service or retry.
class LoopbackLink {
  final Future<Map<String, dynamic>> Function() snapshot;
  final Future<String> Function(Envelope) command;
  final void Function() changed;
  HttpServer? _server;
  Timer? _expiry;
  String? _key;
  String? _armedId;
  int _armedUntil = 0, _serial = 0, _epoch = 0, _active = 0;
  String diagnostic = 'Sessione non avviata';
  final Map<String, (String, Future<Envelope>)> _ledger = {};
  LoopbackLink({
    required this.snapshot,
    required this.command,
    required this.changed,
  });
  bool get running => _server != null;
  String? get pairing => _key == null ? null : '${_server!.port}:$_key';
  bool armed(String id) =>
      running &&
      _armedId == id &&
      DateTime.now().millisecondsSinceEpoch < _armedUntil;
  Future<void> start({int port = 0}) async {
    await stop();
    final epoch = _epoch;
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
      backlog: 4,
    );
    if (epoch != _epoch) {
      await server.close(force: true);
      return;
    }
    _server = server;
    _expiry = Timer(const Duration(minutes: 10), () => stop());
    server.idleTimeout = const Duration(seconds: 3);
    _key = base64UrlEncode(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    ).replaceAll('=', '');
    diagnostic = 'In ascolto solo su 127.0.0.1';
    server.listen(
      (r) => _handle(r, epoch),
      onError: (Object _) {
        diagnostic = 'Errore listener';
        changed();
      },
    );
    changed();
  }

  Future<void> stop() async {
    _expiry?.cancel();
    _expiry = null;
    _epoch++;
    _key = null;
    _armedId = null;
    _armedUntil = 0;
    final server = _server;
    _server = null;
    await server?.close(force: true);
    diagnostic = 'Sessione chiusa; abbinamento invalidato';
    changed();
  }

  void disarm() {
    _armedId = null;
    _armedUntil = 0;
    changed();
  }

  void arm(String id) {
    if (!running) return;
    _armedId = id;
    _armedUntil = DateTime.now().millisecondsSinceEpoch + 60000;
    changed();
  }

  Future<void> _handle(HttpRequest h, int epoch) async {
    _active++;
    h.response.headers.contentType = ContentType.json;
    h.response.headers.set('Cache-Control', 'no-store');
    try {
      // Reject browser-origin requests, including localhost pages. Token is never in a URL.
      if (_active > 4 ||
          epoch != _epoch ||
          _key == null ||
          !RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch(h.headers.value('x-alarm-mac') ?? '') ||
          h.headers.value('origin') != null) {
        h.response.statusCode = HttpStatus.forbidden;
        return;
      }
      if (h.method != 'POST' ||
          !{'/v1/status', '/v1/command'}.contains(h.uri.path) ||
          h.uri.hasQuery) {
        h.response.statusCode = HttpStatus.notFound;
        return;
      }
      if (h.headers.contentType?.mimeType != 'application/json') {
        h.response.statusCode = 415;
        return;
      }
      final bytes = <int>[];
      final stream = StreamIterator(h);
      final watch = Stopwatch()..start();
      try {
        while (await stream.moveNext().timeout(
          Duration(
            milliseconds: 2000 - watch.elapsedMilliseconds.clamp(0, 1999),
          ),
        )) {
          bytes.addAll(stream.current);
          if (bytes.length > 2048) {
            h.response.statusCode = 413;
            return;
          }
          if (watch.elapsedMilliseconds > 2000) {
            h.response.statusCode = 408;
            return;
          }
        }
      } finally {
        await stream.cancel();
      }
      final raw = utf8.decode(bytes);
      if (!_equal(
        h.headers.value('x-alarm-mac')!,
        _mac('${h.uri.path}\n$raw'),
      )) {
        h.response.statusCode = 403;
        return;
      }
      final req = Envelope.parse(raw);
      if (req == null) {
        h.response.statusCode = 400;
        return;
      }
      if (epoch != _epoch) {
        h.response.statusCode = 403;
        return;
      }
      Envelope answer;
      if (h.uri.path == '/v1/status' && req.type == 'CONNECTION_STATUS') {
        final s = await snapshot();
        final candidates = (s['alarms'] as List? ?? [])
            .where((a) => a['state'] == 'UNKNOWN')
            .toList();
        final c =
            candidates.length == 1 && candidates.single['consumed'] != true
            ? candidates.single
            : null;
        final available = s['permission'] == true && s['connected'] == true;
        answer = Envelope(
          'CONNECTION_STATUS',
          req.requestId,
          null,
          DateTime.now().millisecondsSinceEpoch,
          {
            'connected': true,
            'androidAvailable': true,
            'listenerReady': available,
            'candidate': available && c != null
                ? {'id': c['id'], 'armed': armed(c['id'] as String)}
                : null,
          },
        );
        diagnostic = 'Ping/risposta ricevuto da client autenticato';
        changed();
      } else if (h.uri.path == '/v1/command' &&
          {'ALARM_DISMISS', 'ALARM_SNOOZE'}.contains(req.type)) {
        answer = await execute(req, epoch);
      } else {
        h.response.statusCode = 400;
        return;
      }
      final body = jsonEncode(answer.toJson());
      h.response.write(
        jsonEncode({'body': body, 'mac': _mac('response\n$body')}),
      );
    } catch (_) {
      h.response.statusCode = 400;
    } finally {
      _active--;
      try {
        await h.response.close();
      } catch (_) {}
    }
  }

  String _mac(String raw) => Hmac(
    sha256,
    utf8.encode(_key ?? ''),
  ).convert(utf8.encode(raw)).toString();
  bool _equal(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<Envelope> execute(Envelope req, int epoch) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - req.timestamp > 10000 || req.timestamp - now > 5000) {
      return req.error('TIMEOUT');
    }
    final signature = jsonEncode(req.toJson()), old = _ledger[req.requestId];
    if (old != null) {
      return signature == old.$1 ? old.$2 : req.error('INVALID_RESPONSE');
    }
    if (_ledger.length >= 128) return req.error('FAILED');
    // In-memory cache is never cleared during this engine lifetime; native adds durable claim.
    final future = _perform(req, epoch);
    _ledger[req.requestId] = (signature, future);
    return future;
  }

  Future<Envelope> _perform(Envelope req, int epoch) async {
    if (epoch != _epoch || !armed(req.alarmId!)) {
      return req.error('UNSUPPORTED');
    }
    // Single use arming, before any asynchronous native operation.
    _armedId = null;
    _armedUntil = 0;
    changed();
    final s = await snapshot();
    if (epoch != _epoch || !running) return req.error('DISCONNECTED');
    final candidates = (s['alarms'] as List? ?? [])
        .where((a) => a['state'] == 'UNKNOWN')
        .toList();
    if (s['permission'] != true ||
        s['connected'] != true ||
        candidates.length != 1 ||
        candidates.single['id'] != req.alarmId ||
        candidates.single['consumed'] == true) {
      return req.error('ALARM_ENDED');
    }
    final result = await command(req);
    diagnostic = result.startsWith('UNVERIFIED')
        ? 'Intent inviato; esito reale da osservare'
        : 'Comando rifiutato';
    changed();
    if (!result.startsWith('UNVERIFIED')) {
      return req.error(
        result.startsWith('UNSUPPORTED') ? 'UNSUPPORTED' : 'FAILED',
      );
    }
    return Envelope(
      'ALARM_COMMAND_SENT',
      req.requestId,
      req.alarmId,
      DateTime.now().millisecondsSinceEpoch,
      {'phase': 'SENT_UNVERIFIED', 'command': req.type},
    );
  }

  Envelope statusRequest() => Envelope(
    'CONNECTION_STATUS',
    'phone-${++_serial}',
    null,
    DateTime.now().millisecondsSinceEpoch,
    {'connected': true, 'androidAvailable': false},
  );
}
