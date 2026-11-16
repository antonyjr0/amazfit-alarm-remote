# Integrazione Android futura

Nessun codice Android/Flutter è presente in questa fase; non sono stati installati Flutter o Android Studio. La futura applicazione indipendente sarà in `android-app/`.

## Responsabilità Flutter / Kotlin

Flutter presenterà configurazione, associazione e diagnostica. Kotlin gestirà soltanto le capacità native effettivamente verificate: rilevamento suoneria Xiaomi, azioni supportate e relativa verifica dell'esito, lifecycle del canale e permessi. Ogni occorrenza di suoneria, incluso un nuovo squillo dopo snooze, richiede un `alarmId` diverso.

Implementare gli envelope di [COMMUNICATION_PROTOCOL.md](COMMUNICATION_PROTOCOL.md), rifiutare versioni sconosciute e comandi scaduti. Prima di agire controllare che la stessa occorrenza sia ancora attiva. La deduplicazione deve essere persistente sul lato Android, inclusi esiti incerti dopo riavvio. Un nuovo `requestId` non autorizza a ripetere un'azione su un allarme terminato.

Eventi: `ALARM_RINGING` quando il rilevamento è autorevole, `ALARM_STOPPED` alla cessazione autonoma. Risposte: `ALARM_DISMISSED`/`ALARM_SNOOZED` con `phase: EXECUTED` soltanto dopo verifica dello stato effettivo; altrimenti `ERROR` (`UNSUPPORTED`, `ALARM_ENDED`, `FAILED`, ecc.). Non inventare una conferma a seguito della sola consegna di un Intent.

## Canale proposto — DA VERIFICARE

Prima ipotesi: servizio HTTP locale Android, legato esclusivamente al loopback, interrogato dal Side Service tramite fetch ufficiale. Prima di implementarlo occorre dimostrare sperimentalmente accesso a localhost dal runtime Zepp, compatibilità cleartext/rete e disponibilità a telefono bloccato. Il progetto attuale non configura né contatta alcun endpoint.

Se il canale supera la prova, l'adapter dovrà:

1. Autenticare l'istanza Android con un segreto locale stabilito esplicitamente e non registrato nei log.
2. Implementare `status()` sincrono su stato di disponibilità aggiornato, `execute(req)` asincrono, `subscribe(callback)` con funzione di disiscrizione e `close()`.
3. Usare fetch con le opzioni e la gestione `body` documentate da Zepp; validare le risposte col parser condiviso.
4. Pubblicare disponibilità e **snapshot attuale** dopo connessione/ripresa della pagina, quindi gli eventi in ordine. Non limitarsi a riportare Bluetooth connesso.
5. Non ritrasmettere automaticamente comandi offline. Dopo scadenza, chiedere uno snapshot e verificare l'esito prima di offrire nuovi comandi.
6. Conservare l'associazione fra ID, occorrenza e risultato anche se Zepp si riavvia.

Fonti: [Fetch Side Service](https://docs.zepp.com/docs/reference/side-service-api/fetch/), [architettura Zepp](https://docs.zepp.com/docs/1.0/guides/architecture/arc/). Non c'è prova documentale raccolta che Zepp esponga un bridge diretto verso app Android arbitrarie o WebSocket.

Alternative da valutare se localhost fallisce: integrazione ufficiale Zepp/SDK qualora disponibile per app di terze parti, oppure BLE GATT dedicato solo dopo verifica di ruoli e lifecycle. [BLE Central](https://docs.zepp.com/docs/guides/framework/device/ble-central/) documenta capacità hardware generali; non prova la fattibilità di questo canale con Android e background. Non usare server cloud per aggirare il problema.

## Permessi e vincoli da verificare

Gli [Intent Android AlarmClock](https://developer.android.com/reference/android/provider/AlarmClock) definiscono `ACTION_DISMISS_ALARM` e `ACTION_SNOOZE_ALARM` e il permesso `com.android.alarm.permission.SET_ALARM`. Questo non prova che l'app Orologio Xiaomi li gestisca correttamente, che fornisca un esito verificabile o che funzioni a telefono bloccato. Non presumere che l'extra per la durata snooze sia rispettato.

Per il rilevamento valutare, solo se necessario, un NotificationListener autorizzato esplicitamente dall'utente; verificare presenza e azioni delle notifiche Xiaomi. Un allarme pianificato dal sistema non è prova che stia suonando. Valutare servizio foreground, relativi permessi/visibilità e limiti di avvio in background in base alla versione Android. Non richiedere automaticamente permessi per programmare sveglie esatte: questa applicazione non crea sveglie proprie.

Fonti Android per la successiva analisi: [NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService), [servizi foreground](https://developer.android.com/develop/background-work/services/fgs), [restrizioni avvio Activity](https://developer.android.com/guide/components/activities/background-starts). Questi sono punti di verifica, non capacità implementate.

Su HyperOS provare risparmio energetico, avvio automatico autorizzato, processo rimosso, riavvio telefono, schermo bloccato, Doze, più sveglie contemporanee, stop dal telefono e cambio rete/Bluetooth. Registrare versione HyperOS, versione dell'app Orologio e firmware Amazfit per ogni risultato. Non usare Accessibility o API private come scorciatoia.

## Ordine della prossima fase

Prima dimostrare su telefono reale rilevamento e controllo Xiaomi con esito verificabile; in parallelo verificare un canale Zepp–Android supportato. Solo dopo questi due prototipi creare l'app Flutter/Kotlin completa. L'apertura automatica è un vincolo separato: l'eventuale notifica interattiva richiede una decisione di prodotto, perché modifica il requisito originale.
