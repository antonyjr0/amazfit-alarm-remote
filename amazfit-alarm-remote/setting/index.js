AppSettingsPage({
  build({ settingsStorage }) {
    return Section({}, [
      Text({ paragraph: true }, 'Alarm Remote · collegamento sperimentale'),
      Text({ paragraph: true }, 'Avvia una sessione nella schermata Stato dell’app Android. Incolla qui il codice temporaneo porta:chiave. È una credenziale: non condividerla. Per operare mantieni Android visibile e abilita una sola prova.'),
      TextInput({ label: 'Codice sessione Android', value: settingsStorage.getItem('pairing') || '',
        onChange: value => settingsStorage.setItem('pairing', String(value).trim()) }),
      Text({ paragraph: true }, 'I comandi si disabilitano lasciando Android. La sessione scade dopo 10 minuti, chiudendola o terminando il processo. Il codice è conservato nello storage di Zepp finché lo cancelli o sostituisci, ma non riapre sessioni scadute.'),
      Toggle({ label: 'Preferisci posticipo nativo (durata gestita da Orologio)',
        value: settingsStorage.getItem('nativeSnooze') !== 'false',
        onChange: value => settingsStorage.setItem('nativeSnooze', String(value)) }),
      Text({ paragraph: true }, 'Nessuna apertura automatica e nessun comando a schermo bloccato. Un Intent inviato non prova che la sveglia sia spenta.'),
      Text({ paragraph: true }, settingsStorage.getItem('diagnostics') || 'Apri la Mini App per verificare il collegamento.')
    ])
  }
})
