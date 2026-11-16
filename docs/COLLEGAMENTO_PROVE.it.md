# Collegamento sperimentale Zepp ↔ Android

16 novembre 2026. Progetto amazfit-alarm-remote. Branch experiment/zepp-android-link.

## Cosa è stato preparato

Dentro le due applicazioni esistenti, senza app separata, backend o nuove pagine:

`watch/ZML RPC → Side Service dentro Zepp → POST HTTP 127.0.0.1 → server Dart nella dashboard Flutter → MethodChannel → Kotlin → Intent Orologio selezionato`

La risposta percorre lo stesso tragitto al contrario. Il watch interroga lo stato ogni 5 secondi mentre la Mini App è aperta. Non esiste un polling continuo del telefono a watch chiuso, né apertura automatica della Mini App.

È cablato il percorso completo per una **prova assistita con Android visibile**, non un controllo autonomo a telefono bloccato. Il punto ancora non dimostrato è `fetch(http://127.0.0.1)` nel runtime della propria versione Zepp. La documentazione ufficiale garantisce richieste Fetch dal Side Service, non localhost o HTTP sul dispositivo. Il successo del test JS/Dart sul computer non risolve questa incognita.

## Prima prova, senza toccare sveglie

1. Compila/installa entrambe le app dallo stesso branch. Android: cartella `android_alarm_remote/`. Watch/Zepp: cartella `amazfit-alarm-remote/`, `zeus build` / `zeus preview` nel tuo ambiente. Non usare cartelle di syncbeat.
2. Apri Android, scheda Stato, **Avvia collegamento di prova**, poi **Copia codice sessione**. Il codice contiene porta casuale e chiave casuale di 256 bit; è una credenziale temporanea. Non inserirlo in Git, ticket, chat o screenshot. La clipboard è condivisa col sistema: cancellala dopo l'abbinamento.
3. In Zepp, impostazioni della Mini App Alarm Remote, incolla in **Codice sessione Android**. Lo storage Zepp conserva quel valore finché lo cancelli o sostituisci; la chiave da sola non riapre una sessione scaduta.
4. Torna alla dashboard Android e lasciala visibile. Apri manualmente Alarm Remote sull'Active 3 Premium. Entro un ciclo di circa 5 secondi deve mostrare **Collegamento Android attivo**; la diagnostica Android deve registrare **Ping/risposta ricevuto da client autenticato**. Senza candidata, pulsanti non operativi. Nessun comando sveglia parte dal ping.
5. La sessione scade dopo 10 minuti, premendo Chiudi collegamento o terminando il processo. Una nuova sessione genera un altro codice. Spostarsi a Zepp non chiude il server, per permettere l'abbinamento; rende però non operativi eventuali comandi abilitati.

Se il ping non riesce: verifica codice/sessione e watch↔Zepp/Bluetooth, quindi raccogli versione Zepp ed errori con chiave rimossa. Un 403 indica autenticazione/Origin; connessione rifiutata indica porta/sessione; un errore cleartext dal processo Zepp è un limite del client Zepp. **Non** aprire il bind a 0.0.0.0, non disabilitare TLS e non aggiungere `usesCleartextTraffic` a Flutter pensando che cambi la policy dell'app Zepp: sono processi/app diversi. Non avviare un relay cloud o un servizio nativo alternativo automaticamente. Se Zepp blocca questo percorso, fermare la prova e rivalutare il trasporto.

## Prova Spegni/Posticipa, solo dopo il ping

Usa una sveglia creata apposta, mai quella del lavoro o un impegno reale. Annota modello telefono, Android/HyperOS, Orologio Xiaomi, Zepp e firmware watch.

1. Nelle impostazioni Android dell'app scegli esplicitamente il pacchetto Orologio Xiaomi disponibile e concedi Accesso notifiche. Verifica listener connesso.
2. Fai suonare la sveglia di prova. `CATEGORY_ALARM` è solo una **notifica candidata UNKNOWN**, non prova della suoneria. Se non compare, questo rilevamento non è sufficiente per quella versione Xiaomi.
3. Mentre **senti davvero il suono**, torna a Stato e premi **Abilita comandi dal watch**, confermando il dialogo. Abilita un solo invio per 60 secondi, con una sola candidata attuale e non consumata. Non è un'impostazione permanente. Lascia Android visibile.
4. Sul watch comparirà **Notifica candidata / Prova abilitata sul telefono**. Scegli Spegni oppure Posticipa. Il tap è il comando esplicito; nessun comando automatico viene generato dalla notifica.
5. Il risultato atteso del software è **Intent inviato / Esito reale non verificato**, non “sveglia spenta”. Osserva personalmente il suono e qualsiasi scelta proposta da Xiaomi. Android può aprire l'app Orologio: fuori dalla Activity i comandi sono bloccati e l'abilitazione viene rimossa.
6. Per Posticipa aspetta il nuovo squillo e annota ID/consumed. Se Xiaomi aggiorna la stessa notification key senza rimuoverla, il nuovo squillo può rimanere consumato: il rilievo A3 rimane aperto, non lo si aggira azzerando lo stato a ogni aggiornamento.
7. Se perdi la risposta o scade il timeout, **non ripetere automaticamente**: controlla il telefono. Il comando può essere già partito. Chiudi sessione, prova revoca permessi e disconnessione, più candidate e nuova installazione.

## Sicurezza e semantica del protocollo

- Bind solo `InternetAddress.loopbackIPv4`, porta casuale non privilegiata, nessun URL configurabile né LAN. Permesso INTERNET nel Manifest di release, perché il socket deve poter essere aperto; nessun permesso Bluetooth aggiunto a Flutter.
- HMAC-SHA256 su `percorso + newline + corpo esatto`; la chiave non viaggia nelle richieste. Risposta con `{body: string, mac: HMAC('response\n' + body)}` verificata da JS **prima** del parser. Librerie `crypto 3.0.7` (Dart) e `@noble/hashes 1.8.0` (JS, versione fissata). Entrambe nello stack attuale; nessuna crittografia implementata a mano.
- HTTP loopback non cifra i payload. HMAC autentica messaggio e risposta, non protegge un telefono compromesso né una chiave rubata dalla clipboard/storage Zepp. Non vengono inviati titoli/testi delle notifiche, pacchetti o log: solo disponibilità, ID candidato opaco, stato armato e comandi.
- Accettati solo POST `/v1/status` e `/v1/command`, JSON fino a 2048 byte; Origin browser rifiutato, nessun CORS, 4 handler contemporanei, lettura corpo con scadenza, sessione 10 minuti. Questo non è un audit formale né una difesa completa da DoS da altre app locali.
- requestId/alarmId e timestamp validati; vecchie richieste oltre 10 secondi o future oltre 5 rifiutate. Nessun retry dei comandi. Dedup in Dart e JS fino a 128 richieste per vita dell'oggetto, poi fail-closed; registro claim Kotlin persistente e sincrono prima dell'Intent, conservato oltre la finestra di validità. Il claim non è un certificato di esecuzione: dopo crash un risultato incerto non viene rieseguito.
- `CONNECTION_STATUS.payload.candidate={id,armed}|null` rappresenta la candidata, senza falsificare `ALARM_RINGING`. Nuovo tipo `ALARM_COMMAND_SENT` con `phase=SENT_UNVERIFIED` e `command` correlato: non è `ALARM_DISMISSED/ALARM_SNOOZED phase=EXECUTED`.
- Kotlin ricontrolla Activity visibile, listener, candidata unica e non consumata. `alarmId` è interno e non identifica la sveglia in Orologio. Con più sveglie reali gli Intent standard possono mostrare una scelta: una notifica non prova quante sveglie esistano.

## Verifiche riproducibili

```
cd android_alarm_remote
flutter pub get
flutter analyze
flutter test
# nel proprio ambiente Android configurato:
flutter build apk --debug
cd android
./gradlew :app:testDebugUnitTest

cd ../../amazfit-alarm-remote
npm ci
npm test
zeus build

# dalla radice, Dart nello stesso SDK del progetto Flutter:
DART=/percorso/flutter/bin/dart node tools/loopback-smoke.mjs
```

Il test smoke avvia un vero server Dart e usa il client JS con HTTP/HMAC reali. Solo il controllo nativo è uno stub dichiarato: una sola chiamata per duplicati, nessuna prova hardware implicita. `tools/loopback_fixture.dart` è un programma di test locale, non una terza app da distribuire.

## Collaudi rimasti obbligatori

Zepp HTTP/loopback sul telefono, BLE/RPC con Active 3 Premium, supporto e comportamento degli Intent Xiaomi, ritorno dopo snooze, autorizzazioni/revoche, rotazione sessione e riavvio, conflitti tra più sveglie. Non verificati su hardware. Il funzionamento a schermo bloccato, servizio permanente e apertura automatica del watch non sono implementati. Firma release debug e applicationId di esempio restano limiti precedenti; discordanza licenza ISC/MIT non cambiata senza scelta del titolare.

## Fonti rilette

- https://docs.zepp.com/docs/guides/architecture/arc/
- https://docs.zepp.com/docs/guides/framework/side-service/intro/
- https://docs.zepp.com/docs/reference/side-service-api/fetch/
- https://docs.zepp.com/docs/samples/app/fetchAPI/ (l'esempio pubblicato simula la risposta; non prova rete reale)
- https://docs.zepp.com/docs/reference/app-settings-api/ui/textinput/
- https://docs.zepp.com/docs/reference/side-service-api/settings/
- https://api.dart.dev/dart-io/HttpServer/bind.html
- https://developer.android.com/privacy-and-security/security-config
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developer.android.com/reference/android/provider/AlarmClock
