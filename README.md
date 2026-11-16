# Amazfit Alarm Remote

Mini App Zepp OS e applicazione Android Flutter/Kotlin per studiare il controllo della sveglia Xiaomi/HyperOS da Amazfit Active 3 Premium.

**Il controllo dal watch non è operativo.** Sono implementati client orologio, protocollo, macchina a stati, App-side, impostazioni e diagnostica Android con test locali degli Intent dismiss/snooze (esito UNVERIFIED). Il trasporto Android è esplicitamente non configurato: nessuna connessione o esecuzione viene simulata nell'app distribuita.

| Requisito finale | Stato |
| --- | --- |
| Apertura automatica sull'orologio | DA VERIFICARE; non implementata. Il percorso diretto da App Service non è supportato dalle API documentate |
| Comunicazione Zepp OS ↔ app Android esterna | NON ANCORA IMPLEMENTATO; astrazione pronta |
| Spegnimento/posticipo reale Xiaomi | Intent locali IMPLEMENTATI MA DA TESTARE SU HARDWARE; esecuzione non verificata |

## Struttura

```text
amazfit-alarm-remote/             # root repository
├── amazfit-alarm-remote/         # progetto Zeus esistente
│   ├── app.js / app.json / package.json / package-lock.json
│   ├── page/                    # UI Device App
│   ├── app-side/                # servizio in Zepp sul telefono
│   ├── setting/                 # impostazioni Zepp
│   ├── shared/                  # protocollo, stati, bridge astratto
│   ├── test/                    # test Node e host simulato
│   ├── assets/                  # risorse originali del template
│   └── dist/                    # artefatti generati, esclusi da Git
├── docs/
├── README.md
├── LICENSE
└── .gitignore
```

`android_alarm_remote/` contiene il progetto Flutter già inizializzato: UI Material 3 italiana, listener Kotlin, diagnostica e test locali. Il nome reale sostituisce il percorso indicativo `android-app/`. L'entry point Settings generato da Zeus è `setting/index.js`, al singolare.

## Sviluppo e verifica

Ambiente verificato: Windows PowerShell, Node 20.20.2, npm 10.8.2, Zeus CLI 1.9.3, tipi dispositivo 3.0.1, ZML 0.0.43. API level 3.0 mantenuto, schermo di riferimento 466×466. Le dipendenze e i lockfile appartengono solo al progetto annidato.

Eseguire dalla root repository:

```powershell
cd .\amazfit-alarm-remote
npm.cmd ci
npm.cmd test
.\zeus.cmd build
```

Non è necessario reinstallare Zeus o cambiare Node. Su PowerShell, i comandi `.cmd` evitano il blocco degli shim `.ps1` senza cambiare la execution policy.

Su questo PC è disponibile il launcher locale `zeus.cmd`: usare **`.\zeus.cmd`** dalla cartella del progetto. Il launcher usa Node 20.20.2 già installato in nvm, anche quando la versione globale attiva è Node 16, e non cambia la selezione nvm. Sono disponibili anche `npm.cmd run preview` e `npm.cmd run build`.

**Verificato:** 28 test passati, controllo dipendenze riuscito e `zeus build` completato. Il pacchetto `.zab` è in `amazfit-alarm-remote/dist/`. Test unitari e dei componenti con API simulate non dimostrano il funzionamento BLE o la resa grafica sull'orologio.

## Installazione di sviluppo sull'Amazfit

1. Associare l'Active 3 Premium a Zepp e abilitare la modalità sviluppatore nell'app Zepp seguendo la [guida ufficiale](https://docs.zepp.com/docs/guides/tools/zepp-app/).
2. Dalla cartella del progetto Zeus, eseguire `.\zeus.cmd login`, completando personalmente l'accesso all'account sviluppatore.
3. Eseguire `.\zeus.cmd preview` e scegliere il target appropriato se richiesto.
4. Scansionare il QR dal lettore della modalità sviluppatore di Zepp per installare la Mini App. [Procedura Zeus ufficiale](https://docs.zepp.com/docs/guides/tools/cli/).
5. Aprire manualmente **Alarm Remote** sull'orologio e controllare anche la pagina impostazioni in Zepp.

L'installazione non è stata eseguita durante lo sviluppo. In questa versione è atteso lo stato “App Android non disponibile” e i pulsanti inattivi. Non esiste una modalità demo che mostri falsamente il controllo Xiaomi funzionante.

## File e documentazione

Modificati: `.gitignore`, questo README, manifest/entry point/device page/App-side/settings, package e lockfile del progetto. Creati: `shared/{package.json,protocol.js,alarm-machine.js,android-bridge.js}`, `test/{core.test.mjs,components.test.mjs}` e i cinque documenti seguenti. Asset, layout e traduzioni del template sono conservati. Nessun commit, push o modifica del remote.

- [Architettura e transizioni](docs/ARCHITECTURE.md)
- [Protocollo e contratto adapter Android](docs/COMMUNICATION_PROTOCOL.md)
- [Limiti, apertura automatica e fonti ufficiali](docs/TECHNICAL_LIMITATIONS.md)
- [Integrazione Android futura](docs/ANDROID_INTEGRATION.md)
- [Report dei test e checklist hardware](docs/TEST_REPORT.md)

Prossimi passi: collaudare il componente Flutter/Kotlin su Xiaomi, verificare il canale locale Zepp–Android e aggiungere un rilevamento autorevole della suoneria. Risolvere separatamente il requisito di apertura automatica; la notifica interattiva ufficiale è una possibile alternativa, ma richiede un tap e non soddisfa da sola quel requisito.


## Applicazione Android

Il listener rileva notifiche candidate senza presumere che la sveglia stia suonando. Selezionare manualmente Orologio Xiaomi tra i gestori rilevati, poi concedere accesso notifiche. I test locali chiedono conferma prima di inviare Intent reali. Nessuna conferma di esecuzione viene simulata. La durata snooze è gestita dall'app Orologio.

```powershell
cd .\android_alarm_remote
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb install -r .\build\app\outputs\flutter-apk\app-debug.apk
```

Per i test Kotlin dalla cartella `android_alarm_remote/android`: `./gradlew.bat :app:testDebugUnitTest` (usare il JDK Android Studio della configurazione locale). L'applicationId debug è `com.example.android_alarm_remote`; la firma release resta quella debug del template e non è una configurazione per pubblicazione.

Documentazione: [architettura Android](docs/ANDROID_ARCHITECTURE.md), [permessi e HyperOS](docs/ANDROID_PERMISSIONS.md), [ricognizione trasporto e API](docs/ANDROID_TRANSPORT_RESEARCH.md), [report e checklist hardware](docs/ANDROID_TEST_REPORT.md).

## Collegamento di prova, 16 novembre 2026

Il branch sperimentale `experiment/zepp-android-link` collega le app già esistenti
tramite loopback autenticato HMAC. Guida e limiti: [docs/COLLEGAMENTO_PROVE.it.md](docs/COLLEGAMENTO_PROVE.it.md).
Il percorso è pronto per il collaudo assistito, **non verificato su telefono/watch reali**.
Nessuna apertura automatica né funzionamento a schermo bloccato.
