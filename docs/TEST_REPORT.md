# Report di verifica

Data: 5 novembre 2026 (Europe/Rome). Ambiente Windows, Node 20.20.2, npm 10.8.2, Zeus CLI 1.9.3. Nessuna modifica a Node/nvm o reinstallazione globale di Zeus effettuata in questa fase di sviluppo.

## Risultati

| Controllo | Esito |
| --- | --- |
| `npm.cmd test` dal progetto Zeus | 28 test, 28 passati, 0 falliti, 0 saltati |
| `npm.cmd ls --depth=0` | Dipendenze complete: device-types 3.0.1 e ZML 0.0.43 |
| Installazione dipendenze e aggiornamento lockfile | Riusciti; npm ha riportato 0 vulnerabilità per il progetto locale |
| `zeus.cmd build` | Exit code 0; bundling, conversione immagini e compilazione QuickJS completati |
| Archivio generato | `.zab` leggibile; manifest e sette pacchetti `.zpk` presenti |
| Target nel manifest del bundle | Presenti 466×466 round NXP e ZPS, oltre agli altri target generati da Zeus |
| `git diff --check` | Nessun errore di whitespace; avvisi Git di normalizzazione LF/CRLF |
| Installazione / simulatore / hardware reale | Non eseguiti |

Pacchetto finale verificato: `amazfit-alarm-remote/dist/20596-Alarm_Remote-1.0.0-20261105150358.zab`, 226093 byte.

SHA-256: `6B39803FA457BBA15F38DF1C9BB2EF00C796AA4226418C4ADDAE9DF06373EAFC`.

Il bundle contiene il manifest del packager con versione zpm 3.5.0; `zeus -v` riporta zpm 3.4.2. I dati sono riportati come osservati, senza equiparare la versione del packager al runtime dell'orologio. Gli artefatti generati sono esclusi da Git.

## Copertura automatica

`core.test.mjs` verifica validazione JSON e dimensioni, tipi e campi, orario valido, 10000 ID unici, entrambi i comandi, blocco dei doppi tap, differenza SENT/RECEIVED/EXECUTED, correlazione richiesta/risposta, mancata disponibilità Android, duplicati, vecchi eventi, nuova sveglia durante comando, completamento errato, stop dal telefono, disconnessione, timeout, retry esplicito, conservazione degli errori e risposte di trasporto non valide.

Il bridge è verificato con trasporti iniettati nei test: adapter non configurato, errori, eccezioni, due richieste duplicate contemporanee con una sola esecuzione, riuso illecito di ID, comando scaduto e adapter bloccato che va in timeout senza essere richiamato.

`components.test.mjs` esegue i veri entry point pagina/App-side/settings in un host JavaScript con API Zepp simulate. Verifica pulsanti e rendering, comando snooze generato, conferma soltanto dopo EXECUTED, risposta malformata tardiva dopo cambio sveglia, teardown anche con heartbeat pendente, errori del Side Service e persistenza della preferenza tra due render tramite l'interfaccia storage. I wrapper ZML sono sostituiti nell'host di test: questi casi non verificano la libreria Bluetooth né il runtime Zepp.

## Problemi individuati e corretti

- Il template non aveva dipendenze installate né test applicativi: installate le dipendenze locali e sostituito il test segnaposto.
- Il glob `test/*.test.mjs` non era espanso da Node 20 su Windows: comando portabile `node --test test`.
- La risoluzione dei percorsi di Node era bloccata dal sandbox (`EPERM`): verifiche eseguite con l'accesso necessario, senza cambiare permessi o policy del sistema.
- Una risposta tardiva non valida poteva interferire con una nuova sveglia: aggiunto controllo della richiesta pendente prima di elaborare la risposta RPC.
- Evitata la sostituzione del listener BLE gestito da ZML usando il callback `onBleChanged` di BasePage.
- Timer heartbeat ora rilasciato anche in caso di chiusura durante la richiesta; deadline esplicita nel bridge per adapter bloccati.
- Un heartbeat positivo non cancella più il dettaglio di un errore o una conferma terminale.

La compilazione è stata eseguita tre volte con successo, inclusa la versione finale dopo le correzioni. I test finali sono successivi alle modifiche applicative sopra elencate. L'ultimo aggiustamento al logging registra SENT soltanto dopo la consegna del comando alla libreria. Un tentativo di passare `--test-reporter` dopo il percorso dei test è stato rifiutato da Node; il comando documentato `npm.cmd test` è stato poi rieseguito con successo.

## Checklist hardware ancora necessaria

1. Installare con `zeus preview`, verificare target/firmware e leggibilità circolare di titolo, stato e pulsanti su Active 3 Premium.
2. Aprire la Mini App: senza adapter Android deve indicare indisponibilità e non permettere comandi.
3. Verificare settingsStorage reale fra chiusura e riapertura Zepp, e diagnostica del Side Service.
4. Collegare un adapter reale soltanto dopo la verifica del canale locale; collaudare eventi e conferme BLE in entrambe le direzioni.
5. Provare disconnessione Bluetooth, Zepp terminata, Android terminata, riconnessione e recupero dello snapshot senza replay di comandi.
6. Provare duplicati, due sveglie, stop dal telefono, tap ripetuti, snooze seguito da nuova occorrenza e risposte tardive.
7. Provare telefono bloccato e restrizioni energetiche HyperOS. Verificare rilevamento e reale controllo Orologio Xiaomi separatamente dal trasporto.
8. Studiare e collaudare una soluzione ufficiale per background/notifiche. Nessun successo di questi test può essere assunto per app terminata o display spento.

## Stato dei requisiti principali

| Requisito | Stato |
| --- | --- |
| Apertura automatica completa da evento telefonico | DA VERIFICARE; non implementata |
| Apertura diretta da App Service tramite router | NON SUPPORTATO DALLE API DOCUMENTATE nel contesto analizzato |
| Collegamento effettivo Zepp OS ↔ Android esterna | NON ANCORA IMPLEMENTATO |
| Spegnimento / posticipo effettivo Xiaomi | NON ANCORA IMPLEMENTATO |
| Client Zepp, protocollo e gestione eventi | IMPLEMENTATO MA DA TESTARE SU HARDWARE; test automatici superati |

Il pacchetto è compilato e pronto per una prova di installazione, non per dichiarare completato il prodotto end-to-end.
