# Limiti tecnici e verifica delle fonti

Verifica documentale: 5 novembre 2026. Nessun orologio o telefono è stato collegato durante questa implementazione. La compilazione non dimostra l'esecuzione su hardware.

## Compatibilità

La [lista ufficiale dei dispositivi](https://docs.zepp.com/docs/1.0/reference/related-resources/device-list/) riporta Active 3 Premium con API level 4.2 e schermo circolare 466×466, deviceSource `10944768`, `10944769`, `10944771`, `10948867`. Il progetto conserva API minima/target 3.0 e usa solo funzionalità compatibili; il target del template è stato corretto da 480 a 466. Questo costituisce compatibilità documentale, mentre installazione, firmware concreto e resa grafica sono **DA VERIFICARE**.

## Apertura automatica: verifica prioritaria

| Scenario | Capacità documentata / implementazione corrente | Stato |
| --- | --- | --- |
| Mini App già aperta | `BasePage.onCall` riceve gli eventi del Side Service e aggiorna la UI; provato con host simulato | IMPLEMENTATO MA DA TESTARE SU HARDWARE |
| Mini App in background | Questa app non mantiene un App Service; nessun ricevitore dopo uscita | NON ANCORA IMPLEMENTATO |
| Mini App terminata | Nessun meccanismo verificato per avviare la UI da un messaggio telefonico | DA VERIFICARE |
| Orologio sul quadrante | Nessun avvio automatico implementato | NON ANCORA IMPLEMENTATO |
| Schermo spento | Nessun risveglio su evento remoto implementato o garantito | DA VERIFICARE |
| Telefono bloccato | Lifecycle Zepp, disponibilità adapter e controllo Xiaomi non collaudati | DA VERIFICARE |

Il requisito di prodotto **apertura automatica senza intervento dell'utente non è implementato**.

La documentazione [App Service](https://docs.zepp.com/docs/guides/framework/device/app-service/) limita le API utilizzabili dal servizio in background: la superficie UI concessa è la notifica, non il router. Per quel contesto, l'apertura diretta tramite `launchApp` è **NON SUPPORTATO DALLE API DOCUMENTATE**. Non estendiamo questa conclusione a ogni possibile firmware o futura API.

[`launchApp`](https://docs.zepp.com/docs/reference/device-app-api/newAPI/router/launchApp/) è un'API della Device App, non una funzione del Side Service telefonico. La sua esistenza non prova che un evento remoto possa aprire un'app terminata. L'[App-side lifecycle](https://docs.zepp.com/docs/v2/guides/framework/side-service/register/) espone init/run/destroy; non documenta qui un listener Android nativo o un'esecuzione ininterrotta garantita.

L'alternativa ufficiale è [System Notification](https://docs.zepp.com/docs/guides/framework/device/system-notification/): un pulsante può aprire una pagina oppure invocare un App Service. Può costituire una futura superficie per Spegni/Posticipa, ma richiede un servizio attivo, corretta correlazione e test di consegna. Richiede interazione dell'utente; non equivale ad apertura automatica. Non è implementata in questa fase.

## Background e schermo

Un App Service residente richiede autorizzazione background e può essere soggetto a conflitti con altri servizi: una soluzione futura deve collaudare convivenza e consumo. Non è stato aggiunto per simulare una capacità end-to-end ancora assente.

[`setPageBrightTime`](https://docs.zepp.com/docs/reference/device-app-api/newAPI/display/setPageBrightTime/) modifica la durata di illuminazione della pagina corrente, non prova un risveglio remoto. [`setWakeUpRelaunch`](https://docs.zepp.com/docs/reference/device-app-api/newAPI/display/setWakeUpRelaunch/) riguarda il ritorno alla Mini App al risveglio; non viene usato per dichiarare una sveglia remota. Non sono implementati accensione forzata, vibrazione o mantenimento dello schermo.

## Comunicazione

**Documentato:** [BLE Device App](https://docs.zepp.com/docs/v2/reference/device-app-api/newAPI/ble/) e [Messaging Side Service](https://docs.zepp.com/docs/v2/reference/side-service-api/messaging/) comunicano tra orologio e Zepp. La serializzazione e il framing sono affidati a ZML ufficiale.

**Documentato:** [Fetch API](https://docs.zepp.com/docs/reference/side-service-api/fetch/) consente richieste HTTP dal Side Service. Le sue opzioni differiscono dal fetch browser: un solo oggetto con `url`, `method`, `headers`, `body`; la risposta espone `body` come oggetto o stringa.

**Non verificato:** accesso da Zepp a `127.0.0.1`, HTTP cleartext locale, porte di un servizio Android, politiche di rete e gestione a schermo bloccato. Non basta la disponibilità di fetch per dichiarare il canale locale utilizzabile. Nessuna API WebSocket arbitraria è stata verificata nella documentazione consultata. Nessun bridge nativo, Intent, Broadcast o socket Android è esposto dal codice App-side di questa fase.

**Implementato:** astrazione `status/execute/subscribe/close`, con adapter non configurato. **Non implementato:** trasporto reale Android, snapshot autorevole alla riconnessione, ricevitore residente, autenticazione del canale locale.

## Persistenza e sicurezza delle azioni

[`settingsStorage`](https://docs.zepp.com/docs/reference/app-settings-api/settings-storage/) persiste le preferenze in Zepp; l'interfaccia è usata realmente, ma la persistenza sul telefono resta da collaudare. Lo stato della sveglia non viene persistito sull'orologio per evitare azioni obsolete dopo riavvio.

I messaggi non sono autenticati dal protocollo: serve un trasporto fidato/autenticato prima di collegare Android. La cache idempotenza è in memoria e limitata alla sessione; i limiti sono descritti nel protocollo. Il sistema futuro deve riconciliare gli esiti incerti e impedire che un retry tardivo agisca su una nuova suoneria.

## Xiaomi / HyperOS

Nessuna API Xiaomi è stata provata. Rilevamento della suoneria, spegnimento, posticipo, durata snooze e funzionamento da telefono bloccato sono **NON ANCORA IMPLEMENTATO** / **DA VERIFICARE** quanto a fattibilità. Non sono stati introdotti hack, API private, modifiche firmware o cloud.
