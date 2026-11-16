import { test } from 'node:test'
import assert from 'node:assert/strict'
import { message, validate, parse, newId } from '../shared/protocol.js'
import { AlarmMachine } from '../shared/alarm-machine.js'
import { AndroidBridge } from '../shared/android-bridge.js'

const status = available => message('CONNECTION_STATUS', null, { connected: true, androidAvailable: available })
const ringing = (id = 'alarm-1', timestamp = 100) => message('ALARM_RINGING', id, { time: '07:30' }, newId(), timestamp)
function active(options) { const m = new AlarmMachine(options); m.receive(status(true)); m.receive(ringing()); return m }
const confirm = req => message(req.type === 'ALARM_DISMISS' ? 'ALARM_DISMISSED' : 'ALARM_SNOOZED', req.alarmId, { phase: 'EXECUTED' }, req.requestId)

test('IDs remain unique within a session', () => assert.equal(new Set(Array.from({ length: 10000 }, newId)).size, 10000))
test('protocol rejects malformed, oversized, unknown and unexecuted confirmations', () => {
  for (const raw of [null, [], '{', {}, message('BOGUS'), { ...ringing(), version: 2 },
    { ...ringing(), requestId: '../secret' }, { ...ringing(), timestamp: NaN },
    message('ALARM_RINGING', 'a', { time: '25:90' }), message('ALARM_DISMISSED', 'a', { phase: 'RECEIVED' }),
    message('ERROR', null, { code: 'BOGUS' }), message('CONNECTION_STATUS', null, {}),
    message('ALARM_SNOOZE', 'a', { duration: 5 }), message('ALARM_RINGING', 'a', { label: 'x'.repeat(3000) })]) assert.equal(parse(raw), null)
  assert.ok(validate(ringing())); assert.ok(parse(JSON.stringify(ringing())))
})
for (const type of ['ALARM_DISMISS', 'ALARM_SNOOZE']) test(`${type}: only exact EXECUTED response succeeds`, () => {
  const m = active(); const req = m.command(type)
  assert.equal(req.type, type); assert.equal(req.alarmId, 'alarm-1'); assert.equal(m.state, 'SENDING_COMMAND')
  assert.equal(m.command(type), null)
  m.sent(req.requestId); assert.equal(m.phase, 'SENT'); assert.equal(m.state, 'WAITING_CONFIRMATION')
  m.received(req.requestId); assert.equal(m.phase, 'RECEIVED'); assert.ok(m.alarm)
  m.receive(confirm(req)); assert.equal(m.state, type === 'ALARM_DISMISS' ? 'DISMISSED' : 'SNOOZED')
  assert.equal(m.phase, 'EXECUTED'); assert.equal(m.enabled, false); m.settle(); assert.equal(m.state, 'IDLE')
})
test('commands require operational Android channel and active alarm', () => {
  const m = new AlarmMachine(); assert.equal(m.command('ALARM_DISMISS'), null)
  m.receive(status(false)); m.receive(ringing()); assert.equal(m.enabled, false)
  m.receive(status(true)); assert.equal(m.state, 'IDLE'); assert.equal(m.command('ALARM_DISMISS'), null)
})
test('duplicates do not clear pending command', () => {
  const m = new AlarmMachine(); m.receive(status(true)); const event = ringing(); m.receive(event)
  const req = m.command('ALARM_DISMISS'); assert.equal(m.receive(event), false)
  m.receive(ringing('alarm-1', 101)); assert.equal(m.pending.requestId, req.requestId)
})
test('new alarm cancels old request; stale confirmation and old ringing ignored', () => {
  const m = active(); const req = m.command('ALARM_DISMISS'); m.receive(ringing('alarm-2', 200))
  assert.equal(m.pending, null); assert.equal(m.receive(confirm(req)), false)
  assert.equal(m.receive(ringing('alarm-1', 300)), false); assert.equal(m.alarm.alarmId, 'alarm-2')
})
test('out of order events and foreign request IDs cannot alter current alarm', () => {
  const m = active(); const req = m.command('ALARM_SNOOZE')
  assert.equal(m.receive({ ...confirm(req), requestId: 'foreign' }), false)
  assert.equal(m.receive(ringing('older', 99)), false)
  assert.equal(m.receive(message('ALARM_STOPPED', 'alarm-1', {}, newId(), 99)), false)
  assert.ok(m.pending)
})
test('timeout permits explicit retry; late confirmation cannot complete retry', () => {
  let now = 0; const m = active({ now: () => now }); const req = m.command('ALARM_DISMISS'); m.sent(req.requestId)
  now = 9999; m.tick(); assert.equal(m.state, 'WAITING_CONFIRMATION')
  now = 10000; m.tick(); assert.equal(m.error, 'TIMEOUT'); assert.ok(m.enabled)
  const retry = m.command('ALARM_DISMISS'); assert.notEqual(req.requestId, retry.requestId)
  m.receive(confirm(req)); assert.equal(m.pending.requestId, retry.requestId)
})
test('disconnect cancels request and requires fresh alarm after reconnect', () => {
  const m = active(); const req = m.command('ALARM_DISMISS'); m.disconnect()
  m.receive(confirm(req)); m.receive(status(true)); assert.equal(m.state, 'IDLE'); assert.equal(m.enabled, false)
})
test('phone stop is authoritative; late confirmation and replay ignored', () => {
  const m = active(); const req = m.command('ALARM_DISMISS')
  m.receive(message('ALARM_STOPPED', 'alarm-1', {}, newId(), 200)); assert.equal(m.state, 'IDLE')
  assert.equal(m.receive(confirm(req)), false); assert.equal(m.receive(ringing('alarm-1', 300)), false)
})
for (const code of ['UNSUPPORTED', 'FAILED', 'ALARM_ENDED', 'ANDROID_UNAVAILABLE']) test(`error ${code} is displayed without success`, () => {
  const m = active(); const req = m.command('ALARM_DISMISS')
  m.receive(message('ERROR', req.alarmId, { code }, req.requestId)); assert.equal(m.state, 'ERROR'); assert.equal(m.error, code)
  assert.equal(m.enabled, code !== 'ALARM_ENDED')
})
test('invalid response cancels pending without falsely executing', () => {
  const m = active(); m.command('ALARM_DISMISS'); m.receive('{'); assert.equal(m.error, 'INVALID_RESPONSE'); assert.equal(m.phase, null)
})
test('wrong completion action is rejected', () => {
  const m = active(); const req = m.command('ALARM_DISMISS')
  m.receive(message('ALARM_SNOOZED', req.alarmId, { phase: 'EXECUTED' }, req.requestId)); assert.equal(m.state, 'ERROR')
})
test('heartbeat preserves failure details until retry or a new event', () => {
  const m = active(); const req = m.command('ALARM_DISMISS'); m.fail(req.requestId, 'FAILED')
  m.receive(status(true)); assert.equal(m.state, 'ERROR'); assert.equal(m.error, 'FAILED')
})
test('unconfigured bridge reports unavailable and never fabricates success', async () => {
  const b = new AndroidBridge(); assert.equal(b.status().payload.androidAvailable, false)
  const result = await b.execute(message('ALARM_DISMISS', 'a')); assert.equal(result.type, 'ERROR'); assert.equal(result.payload.code, 'NOT_CONFIGURED')
  await assert.rejects(b.execute({}), /INVALID_REQUEST/)
})
test('bridge executes concurrent duplicates once and rejects request ID reuse', async () => {
  let executions = 0
  const b = new AndroidBridge({ status: () => ({ available: true }), execute: async req => { executions++; return confirm(req) } })
  const req = message('ALARM_DISMISS', 'a')
  const results = await Promise.all([b.execute(req), b.execute(req)])
  assert.equal(executions, 1); assert.deepEqual(results[0], results[1])
  assert.equal((await b.execute({ ...req, alarmId: 'b' })).payload.code, 'INVALID_RESPONSE')
})
test('bridge rejects stale requests without calling Android', async () => {
  let calls = 0; const b = new AndroidBridge({ execute: () => calls++ })
  assert.equal((await b.execute(message('ALARM_DISMISS', 'a', {}, newId(), Date.now() - 20000))).payload.code, 'TIMEOUT'); assert.equal(calls, 0)
})
test('bridge validates transport responses and failures', async () => {
  for (const execute of [async () => ({}), async req => ({ ...confirm(req), alarmId: 'other' }), async () => { throw Error('private') }]) {
    const result = await new AndroidBridge({ execute }).execute(message('ALARM_DISMISS', 'a'))
    assert.equal(result.type, 'ERROR'); assert.ok(['INVALID_RESPONSE', 'FAILED'].includes(result.payload.code))
  }
})
test('bridge times out a hung transport, caches uncertain result and never repeats operation', async () => {
  let calls = 0
  const bridge = new AndroidBridge({ execute: () => { calls++; return new Promise(() => {}) } }, 5)
  const req = message('ALARM_SNOOZE', 'a')
  const result = await bridge.execute(req)
  assert.equal(result.payload.code, 'TIMEOUT')
  assert.deepEqual(await bridge.execute(req), result); assert.equal(calls, 1)
})
