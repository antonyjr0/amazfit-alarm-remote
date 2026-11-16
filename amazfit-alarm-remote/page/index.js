import * as ui from '@zos/ui'
import { getDeviceInfo } from '@zos/device'
import { connectStatus } from '@zos/ble'
import { BasePage } from '@zeppos/zml/base-page'
import { AlarmMachine } from '../shared/alarm-machine.js'

const labels = {
  IDLE: 'Nessuna sveglia attiva', DISCONNECTED: 'Canale non disponibile', RINGING: 'Sveglia in corso',
  SENDING_COMMAND: 'Invio comando...', WAITING_CONFIRMATION: 'Attendo conferma...',
  DISMISSED: 'Sveglia spenta', SNOOZED: 'Sveglia posticipata', ERROR: 'Comando non riuscito'
}
const errors = {
  DISCONNECTED: 'Orologio disconnesso', PHONE_UNREACHABLE: 'Zepp non raggiungibile', ANDROID_UNAVAILABLE: 'App Android non disponibile',
  TIMEOUT: 'Nessuna conferma. Riprova.', ALARM_ENDED: 'Sveglia già terminata', UNSUPPORTED: 'Comando non supportato',
  INVALID_RESPONSE: 'Risposta non valida', FAILED: 'Operazione fallita', NOT_CONFIGURED: 'Collegamento Android da configurare'
}
Page(BasePage({
  onInit() {
    this.alive = true; this.widgets = null; this.lastContact = 0; this.checking = false; this.generation = 0
    this.machine = new AlarmMachine({ changed: () => this.render() })
    this.clock = setInterval(() => {
      this.machine.tick()
      if (this.lastContact && Date.now() - this.lastContact > 12000) { this.lastContact = 0; this.machine.disconnect('PHONE_UNREACHABLE') }
      this.machine.settle()
    }, 1000)
    this.poll = setInterval(() => this.checkConnection(), 5000)
  },
  onBleChanged(connected) {
    if (!this.alive) return
    if (!connected) { this.generation++; this.checking = false; this.machine.disconnect() }
    else this.checkConnection()
  },
  build() {
    const scale = getDeviceInfo().width / 466
    const text = (y, h, size, color) => ui.createWidget(ui.widget.TEXT, {
      x: 38 * scale, y: y * scale, w: 390 * scale, h: h * scale,
      text_size: size * scale, color, align_h: ui.align.CENTER_H, align_v: ui.align.CENTER_V,
      text_style: ui.text_style.WRAP, text: ''
    })
    this.widgets = { title: text(44, 42, 27, 0xffffff), connection: text(90, 35, 18, 0xaeb8ca),
      state: text(133, 58, 26, 0xffffff), detail: text(193, 46, 19, 0xaeb8ca) }
    this.widgets.title.setProperty(ui.prop.TEXT, 'Sveglia telefono')
    const button = (y, label, action) => ui.createWidget(ui.widget.BUTTON, {
      x: 73 * scale, y: y * scale, w: 320 * scale, h: 62 * scale, radius: 24 * scale,
      text: label, text_size: 25 * scale, color: 0xffffff, normal_color: 0x28303b, press_color: 0x384453,
      click_func: () => this.sendCommand(action)
    })
    this.widgets.dismiss = button(254, 'Spegni', 'ALARM_DISMISS')
    this.widgets.snooze = button(330, 'Posticipa', 'ALARM_SNOOZE')
    this.render(); this.checkConnection()
  },
  render() {
    if (!this.widgets || !this.alive) return
    const m = this.machine
    this.widgets.connection.setProperty(ui.prop.TEXT, m.connected ? 'Telefono disponibile' : 'Collegamento non operativo')
    let label = labels[m.state]
    if (m.pending && m.pending.type === 'ALARM_SNOOZE') label = 'Posticipo in corso...'
    this.widgets.state.setProperty(ui.prop.TEXT, label)
    this.widgets.detail.setProperty(ui.prop.TEXT, m.error ? errors[m.error] || 'Errore di comunicazione' : m.alarm ? m.alarm.payload.time || '' : '')
    for (const key of ['dismiss', 'snooze']) this.widgets[key].setProperty(ui.prop.MORE, {
      normal_color: m.enabled ? (key === 'dismiss' ? 0xb83d42 : 0x246bb3) : 0x28303b,
      color: m.enabled ? 0xffffff : 0x798391
    })
  },
  checkConnection() {
    if (!this.alive || this.checking) return
    if (!connectStatus()) { this.machine.disconnect(); return }
    this.checking = true
    const generation = this.generation
    const deadline = this.statusTimer = setTimeout(() => {
      if (!this.alive || generation !== this.generation) return
      this.generation++; this.checking = false; this.machine.disconnect('PHONE_UNREACHABLE')
    }, 4000)
    this.request({ method: 'alarm.status', params: {} }, { timeout: 4000 }).then(response => {
      if (!this.alive || generation !== this.generation) return
      this.lastContact = Date.now(); this.machine.receive(response)
    }).catch(() => {
      if (this.alive && generation === this.generation) this.machine.disconnect('PHONE_UNREACHABLE')
    }).finally(() => { clearTimeout(deadline); if (generation === this.generation) this.checking = false })
  },
  sendCommand(type) {
    if (!connectStatus()) { this.machine.disconnect(); return }
    const req = this.machine.command(type)
    if (!req) return
    try {
      const response = this.request({ method: 'alarm.command', params: req }, { timeout: 10000 })
      console.log('alarm command SENT')
      this.machine.sent(req.requestId)
      response.then(result => {
        if (!this.alive || !this.machine.pending || this.machine.pending.requestId !== req.requestId) return
        this.machine.received(req.requestId); this.machine.receive(result)
      }).catch(() => { if (this.alive) this.machine.fail(req.requestId, 'PHONE_UNREACHABLE') })
    } catch (_) { this.machine.fail(req.requestId, 'PHONE_UNREACHABLE') }
  },
  onCall(req) { if (this.alive && req && req.method === 'alarm.event') this.machine.receive(req.params) },
  onDestroy() {
    this.alive = false; this.generation++; clearInterval(this.clock); clearInterval(this.poll); clearTimeout(this.statusTimer)
    this.widgets = null
  }
}))
