export const TYPES = ['ALARM_COMMAND_SENT', 'ALARM_RINGING', 'ALARM_DISMISS', 'ALARM_SNOOZE', 'ALARM_DISMISSED', 'ALARM_SNOOZED', 'ALARM_STOPPED', 'CONNECTION_STATUS', 'ERROR']
export const ERRORS = ['DISCONNECTED', 'PHONE_UNREACHABLE', 'ANDROID_UNAVAILABLE', 'TIMEOUT', 'ALARM_ENDED', 'UNSUPPORTED', 'INVALID_RESPONSE', 'FAILED', 'NOT_CONFIGURED']
const commands = ['ALARM_DISMISS', 'ALARM_SNOOZE']
const completions = ['ALARM_DISMISSED', 'ALARM_SNOOZED']
const object = v => v !== null && typeof v === 'object' && !Array.isArray(v)
const id = v => typeof v === 'string' && /^[a-zA-Z0-9_.:-]{1,128}$/.test(v)
let sequence = 0
const session = Math.random().toString(36).slice(2, 12)
export function newId() { return `watch-${session}-${Date.now().toString(36)}-${(++sequence).toString(36)}` }
export function message(type, alarmId = null, payload = {}, requestId = newId(), timestamp = Date.now()) {
  return { version: 1, type, requestId, alarmId, timestamp, payload }
}
export function validate(m) {
  if (!object(m) || m.version !== 1 || !TYPES.includes(m.type) || !id(m.requestId) || !Number.isSafeInteger(m.timestamp) || m.timestamp < 0 || !object(m.payload)) return false
  if (m.alarmId !== null && !id(m.alarmId)) return false
  if (m.type.startsWith('ALARM_') && !id(m.alarmId)) return false
  if (commands.includes(m.type) && (Object.keys(m.payload).length !== 0)) return false
  if (completions.includes(m.type) && m.payload.phase !== 'EXECUTED') return false
  if (m.type === 'ALARM_COMMAND_SENT' && (m.payload.phase !== 'SENT_UNVERIFIED' || !commands.includes(m.payload.command))) return false
  if (m.type === 'CONNECTION_STATUS' && m.payload.candidate != null && (!object(m.payload.candidate) || !id(m.payload.candidate.id) || typeof m.payload.candidate.armed !== 'boolean')) return false
  if (m.type === 'ERROR' && !ERRORS.includes(m.payload.code)) return false
  if (m.type === 'CONNECTION_STATUS' && (typeof m.payload.connected !== 'boolean' || typeof m.payload.androidAvailable !== 'boolean')) return false
  if (m.type === 'ALARM_RINGING' && m.payload.time !== undefined && (typeof m.payload.time !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(m.payload.time))) return false
  try { return JSON.stringify(m).length <= 2048 } catch (_) { return false }
}
export function parse(raw) {
  if (typeof raw === 'string' && raw.length > 2048) return null
  try { const m = typeof raw === 'string' ? JSON.parse(raw) : raw; return validate(m) ? m : null } catch (_) { return null }
}
export function failure(req, code) { return message('ERROR', req.alarmId, { code }, req.requestId) }
export function isCommand(m) { return validate(m) && commands.includes(m.type) }
