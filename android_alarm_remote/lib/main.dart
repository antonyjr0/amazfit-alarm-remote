import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'platform_bridge.dart';
import 'loopback_link.dart';

void main() => runApp(const AlarmRemoteApp());

class AlarmRemoteApp extends StatelessWidget {
  const AlarmRemoteApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Amazfit Alarm Remote',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with WidgetsBindingObserver {
  final bridge = PlatformBridge();
  late final LoopbackLink link;
  Timer? linkTimer;
  NativeSnapshot? data;
  List<ClockApp> apps = [];
  String? error;
  int tab = 0;
  bool busy = false;
  StreamSubscription<NativeSnapshot>? subscription;
  @override
  void initState() {
    super.initState();
    link = LoopbackLink(
      snapshot: bridge.wireSnapshot,
      command: bridge.remoteCommand,
      changed: () {
        if (mounted) setState(() {});
      },
    );
    linkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && link.running) setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);
    subscription = bridge.events.listen(
      (e) {
        if (mounted) setState(() => data = e);
      },
      onError: (Object e) {
        if (mounted) {
          setState(() => error = 'Eventi Android non disponibili');
        }
      },
    );
    refresh();
  }

  Future<void> refresh() async {
    try {
      final s = await bridge.snapshot();
      final a = await bridge.apps();
      if (mounted) {
        setState(() {
          data = s;
          apps = a;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Servizi Android non disponibili. Aprire su Android e riprovare.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) refresh();
    if (s != AppLifecycleState.resumed) link.disarm();
  }

  @override
  void dispose() {
    linkTimer?.cancel();
    unawaited(link.stop());
    subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> invoke(Future<void> Function() action) async {
    try {
      await action();
      await refresh();
    } catch (_) {
      if (mounted) setState(() => error = 'Operazione Android non disponibile');
    }
  }

  Future<void> command(AlarmCommand cmd, String id) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sveglia reale'),
        content: const Text(
          'Il comando può fermare o posticipare una sveglia reale. Conferma solo se sta suonando ora. Android potrebbe aprire una schermata di scelta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confermo: sta suonando'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      final result = await bridge.command(cmd, id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result)));
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Comando fallito');
    }
    if (mounted) setState(() => busy = false);
    await refresh();
  }

  Future<void> startLink() async {
    try {
      await link.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Avvio loopback fallito. Nessun collegamento attivo.',
        );
      }
    }
  }

  Future<void> armRemote(AlarmCandidate a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Abilita una prova remota'),
        content: const Text(
          'Conferma solo se senti suonare adesso una sveglia di prova. Per 60 secondi il watch potrà inviare un solo Spegni o Posticipa. Non è una conferma automatica della suoneria. Mantieni questa app visibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Abilita per 60 secondi'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) link.arm(a.id);
  }

  Widget card(String title, String body) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final alarms = (data?.alarms ?? <AlarmCandidate>[]);
    final children = <Widget>[if (error != null) card('Attenzione', error!)];
    if (tab == 0) {
      children.addAll([
        card(
          link.running
              ? 'Collegamento di prova attivo'
              : 'Collegamento orologio non configurato',
          '${link.diagnostic}. Solo app visibile; niente apertura automatica sul watch.',
        ),
        card(
          'Accesso notifiche',
          '${data?.permission == true ? 'Autorizzato' : 'Da autorizzare'} · listener ${data?.connected == true ? 'connesso' : 'disconnesso'}',
        ),
        card(
          'Orologio selezionato',
          data?.package.isNotEmpty == true ? data!.package : 'Da selezionare',
        ),
        if (!link.running)
          FilledButton(
            onPressed: startLink,
            child: const Text('Avvia collegamento di prova'),
          ),
        if (link.running) ...[
          card(
            'Abbinamento temporaneo',
            'Copia il codice nelle impostazioni Alarm Remote dentro Zepp. Non inviarlo in chat. Scade dopo 10 minuti, chiudendo la sessione o terminando il processo. I comandi sono bloccati fuori dalla schermata.',
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                final pairing = link.pairing;
                if (pairing != null) {
                  await Clipboard.setData(ClipboardData(text: pairing));
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copia codice sessione'),
            ),
          ),
          OutlinedButton(
            onPressed: () => link.stop(),
            child: const Text('Chiudi collegamento'),
          ),
          for (final a in alarms.where(
            (a) => a.state == 'UNKNOWN' && !a.consumed,
          ))
            if (alarms.where((x) => x.state == 'UNKNOWN').length == 1 &&
                data?.connected == true)
              FilledButton(
                onPressed: () => armRemote(a),
                child: Text(
                  link.armed(a.id)
                      ? 'Prova abilitata: un solo comando'
                      : 'Abilita comandi dal watch',
                ),
              ),
        ],
        card('Ultimo comando', data?.lastCommand ?? 'Nessuno'),
        card(
          'Rilevamento prudente',
          'Una notifica non conferma una suoneria. Non vengono emessi eventi ALARM_RINGING senza evidenza autorevole.',
        ),
        ...alarms.map(
          (a) => card('Notifica ${a.state}', '${a.id}\n${a.evidence}'),
        ),
      ]);
    } else if (tab == 1) {
      children.add(
        card(
          'Diagnostica locale',
          'Massimo 100 eventi in memoria. Nessun testo delle notifiche viene letto o salvato.',
        ),
      );
      children.add(
        TextButton(
          onPressed: () => invoke(bridge.clearLogs),
          child: const Text('Cancella eventi'),
        ),
      );
      for (final l in (data?.logs ?? <DiagnosticEvent>[]).reversed) {
        children.add(
          card(
            DateTime.fromMillisecondsSinceEpoch(l.time).toLocal().toString(),
            l.event,
          ),
        );
      }
    } else if (tab == 2) {
      children.add(
        card(
          'Test locale',
          'Solo durante una suoneria reale. Gli Intent standard non provano l’esecuzione: il risultato rimane UNVERIFIED. La durata del posticipo è gestita da Orologio Xiaomi.',
        ),
      );
      final active = alarms.where((a) => a.state == 'UNKNOWN' && !a.consumed);
      final unambiguous = alarms.where((a) => a.state == 'UNKNOWN').length == 1;
      if (active.isEmpty) {
        children.add(
          card(
            'Nessuna notifica candidata',
            'Avvia manualmente una sveglia nell’app Orologio selezionata.',
          ),
        );
      }
      for (final a in active) {
        children.add(card('Notifica candidata', a.id));
        children.add(
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: busy || !unambiguous || data?.connected != true
                    ? null
                    : () => command(AlarmCommand.dismiss, a.id),
                child: const Text('Spegni'),
              ),
              OutlinedButton(
                onPressed: busy || !unambiguous || data?.connected != true
                    ? null
                    : () => command(AlarmCommand.snooze, a.id),
                child: const Text('Posticipa'),
              ),
            ],
          ),
        );
      }
    } else {
      children.add(
        card(
          '1 · Scegli Orologio Xiaomi',
          'Elenco ricavato dagli Intent pubblici disponibili. Verifica nome e pacchetto; nessun pacchetto Xiaomi è presunto.',
        ),
      );
      for (final a in apps) {
        children.add(
          ListTile(
            title: Text(a.label),
            subtitle: Text(a.package),
            trailing: data?.package == a.package
                ? const Icon(Icons.check)
                : null,
            onTap: () => invoke(() => bridge.select(a.package)),
          ),
        );
      }
      if (apps.isEmpty) {
        children.add(
          card(
            'Nessuna app trovata',
            'Orologio potrebbe non dichiarare gli Intent pubblici richiesti.',
          ),
        );
      }
      children.addAll([
        card(
          '2 · Accesso notifiche',
          'Concedi manualmente il permesso nelle impostazioni Android. Il listener filtra subito il pacchetto selezionato.',
        ),
        FilledButton(
          onPressed: () =>
              invoke(() => bridge.settings(SettingsTarget.notifications)),
          child: const Text('Apri accesso notifiche'),
        ),
        card(
          '3 · Verifica HyperOS',
          'Controlla risparmio energetico e avvio automatico nelle impostazioni dell’app, se presenti. Prova schermo bloccato, riavvio e revoca del permesso. Nessuna esenzione viene richiesta automaticamente.',
        ),
        OutlinedButton(
          onPressed: () => invoke(() => bridge.settings(SettingsTarget.app)),
          child: const Text('Apri impostazioni app'),
        ),
        card(
          'Permessi minimi',
          'Nessun servizio di accessibilità, overlay o foreground. Preferenza del pacchetto persistente. Durata snooze gestita da Orologio Xiaomi.',
        ),
      ]);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Amazfit Alarm Remote'),
        actions: [
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: children),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.watch), label: 'Stato'),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: 'Diagnostica',
          ),
          NavigationDestination(icon: Icon(Icons.alarm), label: 'Test locale'),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Impostazioni',
          ),
        ],
      ),
    );
  }
}
