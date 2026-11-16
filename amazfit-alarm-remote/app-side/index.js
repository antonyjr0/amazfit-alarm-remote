import { BaseSideService } from '@zeppos/zml/base-side'
import { AndroidBridge } from '../shared/android-bridge.js'
import { LoopbackTransport } from '../shared/loopback-transport.js'
AppSideService(BaseSideService({
  onInit() {
    this.transport = new LoopbackTransport({ fetcher: options => fetch(options),
      pairing: () => settings.settingsStorage.getItem('pairing') })
    this.bridge = new AndroidBridge(this.transport)
    settings.settingsStorage.setItem('diagnostics', 'Trasporto loopback sperimentale; apri Android e abbina la sessione')
  },
  onRequest(req, res) {
    if (!this.bridge) { res('SERVICE_UNAVAILABLE'); return }
    if (req.method === 'alarm.status') {
      this.transport.refresh().then(status => {
        settings.settingsStorage.setItem('diagnostics', status.payload.androidAvailable ? 'Ping Android confermato' : 'Android non raggiungibile: controlla sessione, codice e restrizioni HTTP di Zepp')
        res(null, status)
      }).catch(() => res('SERVICE_UNAVAILABLE')); return
    }
    if (req.method !== 'alarm.command') { res('UNSUPPORTED'); return }
    this.bridge.execute(req.params).then(result => res(null, result)).catch(() => res('INVALID_REQUEST'))
  },
  onDestroy() { if (this.bridge) this.bridge.close(); this.bridge = null }
}))
