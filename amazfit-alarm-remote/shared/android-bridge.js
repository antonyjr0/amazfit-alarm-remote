import { failure, isCommand, message, parse } from './protocol.js'

// No network or Android capability is implied by this adapter.
export class UnconfiguredTransport {
  status() { return { available: false } }
  subscribe() { return () => {} }
  async execute(req) { return failure(req, 'NOT_CONFIGURED') }
  close() {}
}
export class AndroidBridge {
  constructor(transport = new UnconfiguredTransport(), timeout = 8000) { this.transport = transport; this.timeout = timeout; this.cache = new Map() }
  status() {
    return message('CONNECTION_STATUS', null, { connected: true, androidAvailable: this.transport.status().available === true })
  }
  async execute(raw) {
    const req = parse(raw)
    if (!req || !isCommand(req)) throw new Error('INVALID_REQUEST')
    const existing = this.cache.get(req.requestId)
    if (existing) {
      if (existing.alarmId !== req.alarmId || existing.type !== req.type) return failure(req, 'INVALID_RESPONSE')
      return existing.result
    }
    if (Date.now() - req.timestamp > 10000 || req.timestamp > Date.now() + 5000) return failure(req, 'TIMEOUT')
    // Cache the promise before executing: duplicate packets cannot execute twice.
    if (this.cache.size >= 128) return failure(req, 'FAILED')
    let timer
    const deadline = new Promise(resolve => { timer = setTimeout(() => resolve(failure(req, 'TIMEOUT')), this.timeout) })
    const operation = Promise.resolve().then(() => this.transport.execute(req))
    const result = Promise.race([operation, deadline]).then(rawResult => {
      const response = parse(rawResult)
      const expected = req.type === 'ALARM_DISMISS' ? 'ALARM_DISMISSED' : 'ALARM_SNOOZED'
      if (!response || response.requestId !== req.requestId || response.alarmId !== req.alarmId || ![expected, 'ALARM_COMMAND_SENT', 'ERROR'].includes(response.type) || (response.type === 'ALARM_COMMAND_SENT' && response.payload.command !== req.type)) return failure(req, 'INVALID_RESPONSE')
      return response
    }).catch(() => failure(req, 'FAILED')).finally(() => clearTimeout(timer))
    this.cache.set(req.requestId, { alarmId: req.alarmId, type: req.type, result })
    return result
  }
  close() { this.transport.close() }
}
