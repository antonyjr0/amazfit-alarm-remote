AppSettingsPage({
  build({ settingsStorage }) {
    return Section({}, [
      Text({ paragraph: true }, 'Amazfit Alarm Remote · 1.0.0'),
      Text({ paragraph: true }, 'Configurazione incompleta: app Android e trasporto non ancora disponibili.'),
      Toggle({ label: 'Preferisci posticipo nativo (preferenza per la futura app)',
        value: settingsStorage.getItem('nativeSnooze') !== 'false',
        onChange: value => settingsStorage.setItem('nativeSnooze', String(value)) }),
      Text({ paragraph: true }, 'La durata dipenderà da Orologio Xiaomi. Questa preferenza non modifica ancora il telefono.'),
      Text({ paragraph: true }, 'Notifiche e apertura automatica: non implementate.'),
      Text({ paragraph: true }, settingsStorage.getItem('diagnostics') || 'Diagnostica non disponibile: apri la Mini App.')
    ])
  }
})
