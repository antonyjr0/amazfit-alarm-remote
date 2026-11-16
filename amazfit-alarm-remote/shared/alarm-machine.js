import { message, parse } from './protocol.js'

export const STATES = ['IDLE', 'DISCONNECTED', 'RINGING', 'SENDING_COMMAND', 'WAITING_CONFIRMATION', 'DISMISSED', 'SNOOZED', 'ERROR']
// Only these public operations change state; incoming completions require exact correlation.
export class AlarmMachine {
  constructor({ now = () => Date.now(), timeout = 10000, changed = () => {} } = {}) {
    this.now = now; this.timeout = timeout; this.changed = changed
    this.state = 'DISCONNECTED'; this.connected = false; this.alarm = null
    this.pending = null; this.error = null; this.phase = null
    this.seen = []; this.closed = []; this.lastEvent = -1; this.connectionTime = -1
  }
  emit(state) { this.state = state; this.changed(this) }
  get enabled() { return this.connected && !!this.alarm && !this.pending && ['RINGING', 'ERROR'].includes(this.state) }
  disconnect(code = 'DISCONNECTED') {
    this.connected = false; this.pending = null; this.alarm = null; this.phase = null
    this.error = code; this.emit('DISCONNECTED')
  }
  invalid() { this.pending = null; this.phase = null; this.error = 'INVALID_RESPONSE'; this.emit('ERROR') }
  receive(raw) {
    const m = parse(raw)
    if (!m) { this.invalid(); return false }
    if (this.seen.includes(m.requestId + ':' + m.type)) return false
    if (m.type === 'CONNECTION_STATUS') {
      if (m.timestamp < this.connectionTime) return false
      this.connectionTime = m.timestamp
      const wasConnected = this.connected
      this.connected = m.payload.connected && m.payload.androidAvailable
      if (!this.connected) { this.disconnect(m.payload.androidAvailable ? 'DISCONNECTED' : 'ANDROID_UNAVAILABLE'); return true }
      if (wasConnected && ['ERROR', 'DISMISSED', 'SNOOZED'].includes(this.state)) return true
      this.error = null
      this.emit(this.pending ? this.state : this.alarm ? 'RINGING' : 'IDLE'); return true
    }
    if (m.type === 'ALARM_RINGING') {
      if (!this.connected || this.closed.includes(m.alarmId) || m.timestamp < this.lastEvent) return false
      if (this.alarm && this.alarm.alarmId !== m.alarmId) { this.rememberClosed(this.alarm.alarmId); this.pending = null }
      this.lastEvent = m.timestamp; this.alarm = m; this.error = null
      this.remember(m); this.emit(this.pending ? this.state : 'RINGING'); return true
    }
    if (!this.alarm || m.alarmId !== this.alarm.alarmId) return false
    if (m.type === 'ALARM_STOPPED') {
      if (m.timestamp < this.lastEvent) return false
      this.lastEvent = m.timestamp; this.rememberClosed(m.alarmId)
      this.pending = null; this.alarm = null; this.error = null; this.phase = null
      this.remember(m); this.emit(this.connected ? 'IDLE' : 'DISCONNECTED'); return true
    }
    if (!this.pending || m.requestId !== this.pending.requestId) return false
    if (m.type === 'ERROR') {
      this.pending = null; this.error = m.payload.code; this.phase = null
      if (m.payload.code === 'ALARM_ENDED') { this.rememberClosed(m.alarmId); this.alarm = null }
      this.remember(m); this.emit('ERROR'); return true
    }
    const expected = this.pending.type === 'ALARM_DISMISS' ? 'ALARM_DISMISSED' : 'ALARM_SNOOZED'
    if (m.type !== expected) { this.invalid(); return false }
    this.rememberClosed(m.alarmId); this.remember(m)
    this.pending = null; this.alarm = null; this.error = null; this.phase = 'EXECUTED'
    this.emit(m.type === 'ALARM_DISMISSED' ? 'DISMISSED' : 'SNOOZED'); return true
  }
  remember(m) { this.seen.push(m.requestId + ':' + m.type); if (this.seen.length > 128) this.seen.shift() }
  rememberClosed(id) { if (!this.closed.includes(id)) this.closed.push(id); if (this.closed.length > 128) this.closed.shift() }
  command(type) {
    if (!this.enabled || !['ALARM_DISMISS', 'ALARM_SNOOZE'].includes(type)) return null
    const req = message(type, this.alarm.alarmId)
    this.pending = { ...req, deadline: this.now() + this.timeout }; this.error = null; this.phase = null
    this.emit('SENDING_COMMAND'); return req
  }
  sent(id) { if (this.pending && this.pending.requestId === id) { this.phase = 'SENT'; this.emit('WAITING_CONFIRMATION') } }
  received(id) { if (this.pending && this.pending.requestId === id) { this.phase = 'RECEIVED'; this.emit('WAITING_CONFIRMATION') } }
  fail(id, code = 'FAILED') { if (this.pending && this.pending.requestId === id) { this.pending = null; this.phase = null; this.error = code; this.emit('ERROR') } }
  tick() { if (this.pending && this.now() >= this.pending.deadline) this.fail(this.pending.requestId, 'TIMEOUT') }
  settle() { if (['DISMISSED', 'SNOOZED'].includes(this.state)) { this.phase = null; this.emit(this.connected ? 'IDLE' : 'DISCONNECTED') } }
}
