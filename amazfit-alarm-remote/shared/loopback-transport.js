import { hmac } from '@noble/hashes/hmac'
import { sha256 } from '@noble/hashes/sha256'
import { bytesToHex, utf8ToBytes } from '@noble/hashes/utils'
import { failure, message, newId, parse } from './protocol.js'

export const sign = (key, raw) => bytesToHex(hmac(sha256, utf8ToBytes(key), utf8ToBytes(raw)))
const equal = (a, b) => {
  if (typeof a !== 'string' || a.length !== b.length) return false
  let diff = 0; for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

// Zepp Fetch differs from browser Fetch: a single options object; body may be JSON or string.
export class LoopbackTransport {
  constructor({ fetcher, pairing, now = () => Date.now(), timeout = 2500 }) {
    this.fetcher = fetcher; this.pairing = pairing; this.now = now; this.timeout = timeout
    this.available = false; this.closed = false; this.epoch = 0
  }
  config() {
    const match = /^(\d{1,5}):([A-Za-z0-9_-]{43})$/.exec(this.pairing() || '')
    if (!match || +match[1] < 1024 || +match[1] > 65535) throw new Error('NOT_CONFIGURED')
    return { url: `http://127.0.0.1:${+match[1]}`, token: match[2] }
  }
  status() { return { available: this.available && !this.closed } }
  subscribe() { return () => {} }
  async post(path, request) {
    if (this.closed) throw new Error('DISCONNECTED')
    const config = this.config(), epoch = this.epoch, pairing = this.pairing()
    const body = JSON.stringify(request)
    let timer
    try {
      const response = await Promise.race([
        Promise.resolve().then(() => this.fetcher({ url: config.url + path, method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-Alarm-Mac': sign(config.token, path + '\n' + body) },
          body })),
        new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('TIMEOUT')), this.timeout) })
      ])
      if (epoch !== this.epoch || pairing !== this.pairing()) throw new Error('DISCONNECTED')
      // status is documented in ZML; side-service fetch variants may omit it.
      if (response.status !== undefined && response.status !== 200) throw new Error('ANDROID_UNAVAILABLE')
      const wrapper = typeof response.body === 'string' ? JSON.parse(response.body) : response.body
      if (!wrapper || typeof wrapper.body !== 'string' || wrapper.body.length > 2048 ||
          !equal(wrapper.mac, sign(config.token, 'response\n' + wrapper.body))) throw new Error('INVALID_RESPONSE')
      const parsed = parse(wrapper.body)
      if (!parsed || parsed.requestId !== request.requestId || parsed.alarmId !== request.alarmId ||
          this.now() - parsed.timestamp > 10000 || parsed.timestamp - this.now() > 5000) throw new Error('INVALID_RESPONSE')
      return parsed
    } finally { clearTimeout(timer) }
  }
  async refresh() {
    const req = message('CONNECTION_STATUS', null, { connected: true, androidAvailable: false }, newId(), this.now())
    try {
      const response = await this.post('/v1/status', req)
      if (response.type !== 'CONNECTION_STATUS') throw new Error('INVALID_RESPONSE')
      this.available = response.payload.androidAvailable
      return response
    } catch (_) { this.available = false; return message('CONNECTION_STATUS', null, { connected: true, androidAvailable: false }) }
  }
  async execute(req) {
    try { return await this.post('/v1/command', req) }
    catch (e) {
      this.available = false
      return failure(req, ['NOT_CONFIGURED', 'TIMEOUT', 'INVALID_RESPONSE', 'DISCONNECTED'].includes(e.message) ? e.message : 'ANDROID_UNAVAILABLE')
    }
  }
  close() { this.closed = true; this.available = false; this.epoch++ }
}
