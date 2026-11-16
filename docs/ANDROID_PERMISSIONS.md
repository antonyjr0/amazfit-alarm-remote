# Permessi Android e HyperOS

## Implementati

1. Accesso notifiche: aprire Impostazioni nell'app, selezionare Orologio Xiaomi dall'elenco rilevato e aprire «Accesso notifiche». Abilitare manualmente «Diagnostica sveglie Orologio». Android rende tecnicamente disponibili le notifiche al listener; il codice filtra subito il pacchetto scelto e non legge testi, titoli o etichette delle azioni. È possibile revocare il consenso nello stesso pannello.
2. `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` protegge il servizio: è richiesto al chiamante sistema, non un permesso runtime concesso all'app.
3. `com.android.alarm.permission.SET_ALARM`: necessario per invocare gli Intent pubblici AlarmClock. L'app non programma sveglie.
4. `<queries>` limitate a SHOW_ALARMS, DISMISS_ALARM e SNOOZE_ALARM, oltre alla query PROCESS_TEXT del template Flutter. Servono a rilevare sul dispositivo i gestori pubblici, non è richiesto QUERY_ALL_PACKAGES.

Nessuna richiesta di notifiche proprie, sveglie esatte, overlay, accessibilità, esenzione batteria, posizione o foreground service. Il manifest debug Flutter conserva INTERNET per gli strumenti di sviluppo; il codice applicativo non apre connessioni di rete.

## Verifica manuale HyperOS

Aprire «Impostazioni app» dal pannello dell'app. Controllare risparmio batteria e avvio automatico dove esposti dalla versione HyperOS; i nomi possono differire. Non esiste qui un bypass o un'esenzione automatica. Dopo riavvio verificare che il listener torni connesso e riconcili le notifiche. Ripetere con schermo bloccato, Doze, risparmio energetico, app rimossa dai recenti e arresto forzato. Dopo arresto forzato può essere necessario aprire di nuovo l'app e verificare l'accesso notifiche.

I test degli Intent richiedono Activity visibile e conferma esplicita. Il comando remoto a telefono bloccato non è implementato; richiederebbe una strategia pubblica compatibile con le restrizioni di avvio Activity e una verifica effettiva della suoneria. Non attivare accessibilità come soluzione implicita.
