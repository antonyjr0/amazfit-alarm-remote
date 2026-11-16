# Protocollo v1

Il protocollo applicativo è JSON; ZML gestisce il framing binario BLE tra Device App e Zepp. Non usare JSON grezzo su `peerSocket` contro questo client ZML. Il futuro adapter Android potrà usare un altro trasporto mantenendo il medesimo envelope applicativo.

## Envelope

```json
{"version":1,"type":"ALARM_SNOOZE","requestId":"watch-session-time-1","alarmId":"phone-occurrence-42","timestamp":1793887200000,"payload":{}}
```

- `version`: esattamente 1.
- `type`: uno dei tipi nella tabella sotto.
- `requestId`: identificativo evento o richiesta, 1–128 caratteri `[a-zA-Z0-9_.:-]`. Nelle risposte al comando è identico alla richiesta. Gli eventi autonomi hanno nuovi ID.
- `alarmId`: ID univoco di una **occorrenza**, obbligatorio per tutti gli `ALARM_*`; `null` ammesso per connessione ed errori non riferiti a una sveglia. Non riusare lo stesso ID per una nuova suoneria dopo snooze.
- `timestamp`: intero non negativo, millisecondi Unix. Gli eventi del telefono devono essere ordinabili e coerenti nello stesso dominio temporale; il futuro adapter deve gestire variazioni dell'orologio del telefono.
- `payload`: oggetto, mai array/null. Envelope serializzato al massimo 2048 caratteri JavaScript. Non includere etichette personali, credenziali o token.

`newId()` combina una componente casuale di sessione, tempo e contatore: verifica di unicità locale, non autenticazione o sicurezza crittografica. L'adapter futuro deve autenticare il trasporto separatamente.

| Tipo | Direzione | Payload |
| --- | --- | --- |
| ALARM_RINGING | Telefono → watch | `{}` oppure `{"time":"07:30"}` (24 ore, HH:mm) |
| ALARM_DISMISS | Watch → telefono | `{}` |
| ALARM_SNOOZE | Watch → telefono | `{}`; nessuna durata arbitraria |
| ALARM_DISMISSED | Telefono → watch | `{"phase":"EXECUTED"}` |
| ALARM_SNOOZED | Telefono → watch | `{"phase":"EXECUTED"}` |
| ALARM_STOPPED | Telefono → watch | `{}`; cessazione autonoma della suoneria |
| CONNECTION_STATUS | Zepp → watch | `{"connected":true,"androidAvailable":false}` |
| ERROR | Risposta / diagnostica | `{"code":"NOT_CONFIGURED"}` |

Campi payload aggiuntivi non sostituiscono quelli obbligatori; i comandi accettano soltanto payload vuoto. Tipi e versioni sconosciuti vengono rifiutati. Il componente App-side rifiuta richieste malformate anche a livello RPC (`INVALID_REQUEST`), senza tentare l'esecuzione.

## Correlazione ed esito

1. `SENT`: il client ha passato il messaggio alla libreria. Nessuna prova di ricezione sul telefono.
2. `RECEIVED`: il client ha ricevuto una risposta RPC; non è prova di esecuzione.
3. `EXECUTED`: risposta applicativa valida del tipo atteso, con `requestId` e `alarmId` identici alla richiesta e `payload.phase` uguale a `EXECUTED`. Solo allora la UI mostra successo.

```json
{"version":1,"type":"ALARM_SNOOZED","requestId":"watch-session-time-1","alarmId":"phone-occurrence-42","timestamp":1793887201000,"payload":{"phase":"EXECUTED"}}
```

Lo stato reale deve essere verificato da Android: avviare un Intent, consegnare un messaggio o ricevere HTTP 200 non basta. Una conferma di spegnimento non può completare una richiesta snooze e viceversa. Dopo timeout, nuova sveglia o stop, una risposta tardiva non cambia più lo stato.

## RPC ZML

- `alarm.status`, `params: {}` → envelope `CONNECTION_STATUS`.
- `alarm.command`, `params: envelope` → envelope risposta esecuzione/errore.
- `alarm.event`, `params: envelope`, tramite `call` dal Side Service → eventi asincroni.

`connected:true` nel messaggio restituito da Zepp significa che il servizio sta rispondendo al client; il canale operativo richiede anche `androidAvailable:true`. Il client verifica separatamente il Bluetooth e la freschezza del contatto. L'adapter attuale restituisce sempre Android indisponibile.

## Scadenze e deduplicazione

Watch: timeout comando 10 s. App-side: deadline operazione 8 s; scarta richieste più vecchie di 10 s o oltre 5 s nel futuro. La sincronizzazione degli orologi deve essere verificata su hardware. Nessuna coda offline e nessun replay automatico dopo riconnessione. Un retry richiede un tap esplicito e genera un nuovo ID; Android deve rileggere lo stato prima di agire.

Il bridge mantiene una cache di 128 richieste per sessione, inclusi risultati/timeout e operazioni pendenti; i duplicati identici condividono la stessa Promise. Riusare un ID per un altro allarme/comando produce `INVALID_RESPONSE`. A cache piena vengono rifiutate nuove operazioni con `FAILED`, finché il Side Service viene ricreato. È una scelta conservativa per non dimenticare deduplicazioni: prima dell'uso reale servirà un registro Android persistente con TTL e riconciliazione. Il timeout locale non può annullare un'azione Android già iniziata; l'adapter deve impedire esecuzioni obsolete e fornire lo stato autorevole dopo il timeout.

## Errori

`DISCONNECTED`, `PHONE_UNREACHABLE`, `ANDROID_UNAVAILABLE`, `TIMEOUT`, `ALARM_ENDED`, `UNSUPPORTED`, `INVALID_RESPONSE`, `FAILED`, `NOT_CONFIGURED`.

Gli errori di comando mantengono la sveglia per un possibile tentativo manuale, salvo `ALARM_ENDED`. Un heartbeat indisponibile o una disconnessione eliminano lo stato attivo e disabilitano i pulsanti. I messaggi diagnostici registrano solo fase/tipo, senza payload personali.
