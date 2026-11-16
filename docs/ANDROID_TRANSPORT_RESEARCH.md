# Ricognizione Android / Zepp

Verifica documentale: 16 novembre 2026. Nessun Xiaomi o Amazfit usato per le prove. «Documentato» descrive una API pubblica, non la compatibilità HyperOS.

| Capacità | Evidenza e scelta | Stato |
| --- | --- | --- |
| Ricezione notifiche | NotificationListenerService offre callback di connessione, notifiche e rimozioni; snapshot dopo connessione | Documentato e implementato; da provare su Xiaomi |
| Rilevamento suoneria Xiaomi | `CATEGORY_ALARM` è solo un indizio; nessuna semantica Xiaomi verificata. Stato UNKNOWN anche con fullscreen | DA VERIFICARE; rilevamento autorevole NON IMPLEMENTATO |
| Scoperta Orologio | PackageManager interroga gestori di Intent pubblici; scelta esplicita persistente, nessun package inventato | Implementato; da provare su Xiaomi |
| Dismiss / snooze | AlarmClock definisce Intent, possibile selezione interattiva e permesso SET_ALARM. Invio locale al pacchetto selezionato non dimostra esecuzione | Documentato; implementato con UNVERIFIED; da provare su Xiaomi |
| Notification.Action / PendingIntent | API pubbliche disponibili, ma nessun identificatore semantico Xiaomi verificato per spegnimento/posticipo. Le etichette non bastano | Strategia NON IMPLEMENTATA; conteggio azioni in diagnostica |
| Accessibilità | Richiede ulteriore consenso, fragile rispetto a UI e lingua | NON IMPLEMENTATO, non richiesto |
| Background | Listener gestito da Android, disponibilità e reboot soggetti al sistema/OEM. Nessun FGS necessario per questo prototipo diagnostico | Documentato; HyperOS DA VERIFICARE |
| Zepp Fetch → localhost | Fetch documenta HTTP e body specifico del runtime, non garantisce loopback/cleartext/background verso app esterna | DA VERIFICARE; server NON IMPLEMENTATO |
| WebSocket / BLE diretto | Messaging collega Side Service e Device App tramite Zepp; non è un bridge Android esterno. Nessuna API raccolta dimostra canale arbitrario | Sconosciuto per questo uso; NON IMPLEMENTATO |
| Apertura automatica watch | App Service ha API limitate; router escluso dal contesto del servizio. Nessuna prova di avvio UI da Side Service telefonico | NON IMPLEMENTATO; apertura diretta dal servizio NON SUPPORTATA DALLE API DOCUMENTATE |

## Fonti ufficiali consultate

- [NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService): callback, autorizzazione e lifecycle.
- [AlarmClock](https://developer.android.com/reference/android/provider/AlarmClock): DISMISS_ALARM, SNOOZE_ALARM e relative limitazioni.
- [Notification.Action](https://developer.android.com/reference/android/app/Notification.Action): actionIntent e semantica delle azioni; nessun mapping Xiaomi ottenuto.
- [Avvio Activity](https://developer.android.com/guide/components/activities/background-starts): restrizioni degli avvii, motivo per limitare gli Intent al test con UI visibile.
- [Zepp Fetch](https://docs.zepp.com/docs/v2/reference/side-service-api/fetch/): parametri url/method/headers/body e differenze del body fra modelli.
- [Architettura Zepp](https://docs.zepp.com/docs/guides/architecture/arc/): Side Service dentro Zepp, accesso a server tramite Fetch.
- [Zepp App Service](https://docs.zepp.com/docs/guides/framework/device/app-service/): contesto senza UI e limitazioni API.
- [Messaging](https://docs.zepp.com/docs/v2/reference/side-service-api/messaging/): collegamento con Device App, non normale app Android.

## Prossimi esperimenti necessari

1. Sullo Xiaomi registrare versioni OS/Orologio e confrontare categoria, ongoing, fullscreen e numero azioni durante sveglia programmata, suoneria, snooze e fine. Non esportare testi personali. Definire una regola autorevole soltanto con evidenza sufficiente.
2. Provare separatamente i due Intent mentre la sveglia suona, documentando UI di selezione, effettivo silenzio e ripresa dopo snooze. La rimozione della notifica da sola non dimostra quale azione sia avvenuta.
3. In un esperimento dedicato dimostrare Fetch dal vero Side Service verso loopback, politiche cleartext, lifecycle Zepp e disponibilità a schermo bloccato. Nessun endpoint di produzione fino alla verifica; poi autenticazione, snapshot ordinato e registro persistente.
4. Verificare sul watch un meccanismo ufficiale di ricezione in background e apertura UI. Un'eventuale notifica interattiva richiede una decisione di prodotto: non soddisfa l'apertura automatica.
