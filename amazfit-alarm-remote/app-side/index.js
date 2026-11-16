import { BaseSideService } from '@zeppos/zml/base-side'
import { AndroidBridge } from '../shared/android-bridge.js'
import { parse } from '../shared/protocol.js'
AppSideService(BaseSideService({
  onInit() {
    this.bridge = new AndroidBridge()
    settings.settingsStorage.setItem('diagnostics', 'Zepp avviato; trasporto Android non configurato')
    this.unsubscribe = this.bridge.transport.subscribe(raw => {
      const event = parse(raw)
      if (event && ['ALARM_RINGING', 'ALARM_STOPPED', 'CONNECTION_STATUS', 'ERROR'].includes(event.type)) {
        this.call({ method: 'alarm.event', params: event })
      }
    })
  },
  onRequest(req, res) {
    if (!this.bridge) { res('SERVICE_UNAVAILABLE'); return }
    if (req.method === 'alarm.status') { res(null, this.bridge.status()); return }
    if (req.method !== 'alarm.command') { res('UNSUPPORTED'); return }
    this.bridge.execute(req.params).then(result => {
      console.log('alarm command RECEIVED; result type', result.type)
      res(null, result)
    }).catch(() => res('INVALID_REQUEST'))
  },
  onDestroy() { if (this.unsubscribe) this.unsubscribe(); if (this.bridge) this.bridge.close(); this.bridge = null }
}))
