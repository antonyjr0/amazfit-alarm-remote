# Report Android

16 novembre 2026, Europe/Rome. Progetto esistente: `android_alarm_remote/`. Flutter 3.44.8, Dart 3.12.2 (versioni riportate dalla build); Gradle wrapper 9.1.0, JDK di Android Studio già installato. Nessuna installazione globale, commit, push o modifica al progetto watch.

## Verifiche eseguite

| Comando | Risultato |
| --- | --- |
| `flutter pub get` | Exit 0; dipendenze risolte. Nessuna nuova dipendenza runtime |
| `dart format lib test` | Sorgenti formattati |
| `flutter analyze` | Exit 0, No issues found |
| `flutter test` | 8 test superati: 7 protocollo/sessione + 1 widget/interazione |
| `./gradlew.bat :app:testDebugUnitTest --console=plain` | Exit 0; 6 test Kotlin, 0 errori/fallimenti/saltati nei due report XML |
| `flutter build apk --debug` | Exit 0, APK generato; prima build 129,6 s, rigenerazione 9,1 s, verifica finale 4,8 s |
| `git diff --check` | Nessun errore sulle modifiche tracciate |
| Installazione, emulatore, Xiaomi, Amazfit | NON ESEGUITI |

APK: `android_alarm_remote/build/app/outputs/flutter-apk/app-debug.apk`, 160812454 byte. SHA-256: `137B239299201B860DA06C3CCE00F1A3A05316C6377F3EF90ED009F344036EA3`.

L'APK è debug, comprende gli strumenti Flutter e usa l'applicationId del template `com.example.android_alarm_remote`. Non è un pacchetto release per pubblicazione.

Gli strumenti Flutter richiedevano accesso alla cache esterna al workspace: la prima esecuzione limitata di `pub get`, rimasta senza output, è stata interrotta. Le verifiche sono riuscite con l'accesso necessario. I primi rilievi dell'analizzatore erano di stile (parentesi graffe/interpolazioni) e sono stati corretti. Gradle riporta avvisi preesistenti della configurazione Flutter/AGP: opzioni `android.builtInKotlin=false` e `android.newDsl=false` deprecate e versione Kotlin embedded diversa. Non sono state modificate versioni globali o migrate configurazioni non necessarie alla build.

## Copertura e limiti

Dart: validazione envelope, dimensione, payload, ID, errori, adapter non configurato, richieste scadute/future, duplicati concorrenti, riuso ID, timeout e risposte tardive, disconnessione/nuova occorrenza, completamento sbagliato e correlazione. Il widget test usa canali nativi simulati: verifica bridge indisponibile, annullamento e conferma prima dell'invio locale. Non prova Android reale.

Kotlin: metadata delle notifiche non equivalgono a suoneria, esclusione riepiloghi e categorie estranee; store con generatore di ID fake: aggiornamenti conservano l'occorrenza, consumo impedisce ripetizioni, rimozione non conferma successo, nuova occorrenza ottiene nuovo ID, due candidate bloccano il comando ambiguo, riconciliazione/ripulitura e limiti di memoria. I test JVM non esercitano un vero NotificationListener, PendingIntent o Orologio Xiaomi.

## Stato dei requisiti

| Requisito | Etichetta e limite |
| --- | --- |
| UI italiana, conferma locale e protocollo/guardia di sessione | IMPLEMENTATO E VERIFICATO con test automatici; rendering Android reale da provare |
| Listener, scoperta pacchetto, snapshot e preferenza persistente | IMPLEMENTATO MA DA TESTARE SU HARDWARE |
| Suoneria Xiaomi confermata, ALARM_RINGING / ALARM_STOPPED autorevoli | NON IMPLEMENTATO; DA VERIFICARE quali evidenze pubbliche siano disponibili |
| DISMISS / SNOOZE tramite Intent locale | IMPLEMENTATO MA DA TESTARE SU HARDWARE; consegna = UNVERIFIED |
| Conferma EXECUTED Xiaomi | NON IMPLEMENTATO; nessuna conferma fittizia |
| PendingIntent delle notifiche / accessibilità | NON IMPLEMENTATO; nessuna mappatura Xiaomi verificata / nessun consenso accessibilità richiesto |
| Adapter astratto e NotConfiguredTransport | IMPLEMENTATO E VERIFICATO |
| Canale Android ↔ Zepp reale e registro remoto persistente | NON IMPLEMENTATO; fattibilità canale DA VERIFICARE |
| Apertura automatica sull'Amazfit | NON IMPLEMENTATO; DA VERIFICARE su hardware |
| Apertura diretta dal contesto App Service tramite router | NON SUPPORTATO DALLE API DOCUMENTATE nel contesto analizzato |

## File principali creati o modificati

- `android_alarm_remote/lib/main.dart`, `platform_bridge.dart`, `protocol.dart`.
- `android_alarm_remote/android/app/src/main/kotlin/com/example/android_alarm_remote/`: `MainActivity.kt`, `AlarmListener.kt`, `AlarmRepository.kt`, `AlarmEvidence.kt`, `OccurrenceStore.kt`.
- Manifest Android: servizio listener protetto, SET_ALARM e query Intent; `android/app/build.gradle.kts`: JUnit solo per test.
- `test/protocol_test.dart`, `test/dashboard_test.dart`; sostituito test contatore del template. Test Kotlin: `AlarmEvidenceTest.kt`, `OccurrenceStoreTest.kt`.
- README principale e Android; `docs/ANDROID_ARCHITECTURE.md`, `ANDROID_PERMISSIONS.md`, `ANDROID_TRANSPORT_RESEARCH.md`, questo report; aggiornati i riferimenti di `ANDROID_INTEGRATION.md` e `ARCHITECTURE.md`. Contratto `COMMUNICATION_PROTOCOL.md` e sorgenti Zepp preservati.

## Installazione e collaudo sullo Xiaomi

Abilitare manualmente debug USB e autorizzare il computer. Dalla root repository, con adb nel PATH:

```powershell
adb devices
adb install -r .\android_alarm_remote\build\app\outputs\flutter-apk\app-debug.apk
```

Aprire Amazfit Alarm Remote dal telefono. In Impostazioni selezionare il gestore corrispondente a Orologio Xiaomi; abilitare manualmente Accesso notifiche. Controllare autorizzazione e listener connesso nella dashboard. Nessuna sveglia viene creata dall'app.

1. Annotare modello, Android/HyperOS, versione Orologio/Zepp, firmware watch. Programmare manualmente una sveglia di prova non importante in Orologio Xiaomi.
2. Confrontare dashboard e log prima, durante e dopo la suoneria. La notifica pianificata non deve essere scambiata per RINGING. Se categoria assente, nessuna candidata è attesa: documentare il blocco.
3. Mentre suona davvero, aprire Test locale: provare prima Annulla, poi confermare Spegni. Annotare schermate di scelta, arresto effettivo, latenza e risultato UNVERIFIED. Ripetere con una nuova occorrenza per Posticipa e verificare ripresa secondo la durata nativa Xiaomi. Una candidata già consumata non viene riprovata automaticamente.
4. Provare due sveglie, aggiornamenti della stessa notifica, rimozione dal telefono, squilli consecutivi e nuova suoneria dopo snooze. Con più candidate il comando è rifiutato.
5. Verificare ricezione con schermo bloccato, Doze, battery saver, recenti rimossi, arresto forzato e reboot; poi aprire la UI per i comandi locali. Non interpretare questo come controllo remoto a schermo bloccato.
6. Revocare accesso notifiche durante una candidata, poi riconcederlo. Verificare stato indisponibile, nessuna azione obsoleta e riconciliazione.
7. Provare Zepp aperta/chiusa, watch connesso/disconnesso: questa versione deve sempre indicare collegamento non configurato, senza eventi o conferme inventati.
8. Solo dopo il prototipo di trasporto documentato: autenticazione, snapshot, perdita collegamento, duplicati, richieste oltre 10 s e risposte tardive; aggiungere registro persistente prima di permettere comandi remoti.

Blocchi di prodotto: evidenza autorevole della suoneria e dell'esito, canale locale Zepp effettivamente raggiungibile, apertura automatica watch. Vedere gli esperimenti concreti in [ANDROID_TRANSPORT_RESEARCH.md](ANDROID_TRANSPORT_RESEARCH.md).
