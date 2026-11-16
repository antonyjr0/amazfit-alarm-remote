import { test } from 'node:test'
import assert from 'node:assert/strict'
import { LoopbackTransport, sign } from '../shared/loopback-transport.js'
import { AndroidBridge } from '../shared/android-bridge.js'
import { AlarmMachine } from '../shared/alarm-machine.js'
import { message, parse } from '../shared/protocol.js'
const pairing = `45678:${'A'.repeat(43)}`
const reply = req => {
  const body = JSON.stringify(message('CONNECTION_STATUS', null,
    { connected: true, androidAvailable: true, candidate: { id: 'candidate-1', armed: true } }, req.requestId))
  return { status: 200, body: { body, mac: sign('A'.repeat(43), 'response\n' + body) } }
}

test('loopback posts to fixed IPv4 only with auth, request correlation and JSON/string responses', async () => {
  const calls = []
  const t = new LoopbackTransport({ pairing: () => pairing, fetcher: async options => {
    calls.push(options); const result = reply(JSON.parse(options.body)); result.body = JSON.stringify(result.body); return result
  } })
  const s = await t.refresh()
  assert.equal(s.payload.androidAvailable, true)
  assert.equal(calls[0].url, 'http://127.0.0.1:45678/v1/status')
  assert.equal(calls[0].headers['X-Alarm-Mac'], sign('A'.repeat(43), '/v1/status\n' + calls[0].body))
  assert.ok(!calls[0].body.includes('A'.repeat(43)))
  assert.equal(calls[0].method, 'POST'); assert.equal(t.status().available, true)
})
test('no arbitrary destination, missing/invalid pairing never sends', async () => {
  for (const value of ['', 'https://evil.test', '80:' + 'A'.repeat(43), '65536:' + 'A'.repeat(43), pairing + '?x']) {
    let calls = 0
    const t = new LoopbackTransport({ pairing: () => value, fetcher: () => calls++ })
    assert.equal((await t.refresh()).payload.androidAvailable, false); assert.equal(calls, 0)
  }
})
test('wrong response ID, HTTP failure, stale response and timeout remain unavailable', async () => {
  for (const response of [ { status: 403, body: {} }, reply({ requestId: 'foreign' }),
      { body: message('CONNECTION_STATUS', null, { connected: true, androidAvailable: true }, 'foreign', 0) } ]) {
    const t = new LoopbackTransport({ pairing: () => pairing, fetcher: async () => response })
    assert.equal((await t.refresh()).payload.androidAvailable, false)
  }
  const t = new LoopbackTransport({ pairing: () => pairing, fetcher: () => new Promise(() => {}), timeout: 1 })
  assert.equal((await t.refresh()).payload.androidAvailable, false)
})
test('closed or changed pairing rejects delayed authenticated reply', async () => {
  for (const close of [true, false]) {
    let finish, current = pairing
    const t = new LoopbackTransport({ pairing: () => current, fetcher: options => new Promise(resolve => { finish = () => resolve(reply(JSON.parse(options.body))) }) })
    const result = t.refresh(); await new Promise(r => setImmediate(r))
    if (close) t.close(); else current = `45679:${'B'.repeat(43)}`
    finish(); assert.equal((await result).payload.androidAvailable, false)
  }
})
test('candidate is not RINGING, must be armed, sent Intent is never EXECUTED', async () => {
  const m = new AlarmMachine()
  m.receive(message('CONNECTION_STATUS', null, { connected: true, androidAvailable: true, candidate: { id: 'candidate-1', armed: false } }))
  assert.equal(m.state, 'CANDIDATE'); assert.equal(m.enabled, false)
  m.receive(message('CONNECTION_STATUS', null, { connected: true, androidAvailable: true, candidate: { id: 'candidate-1', armed: true } }))
  assert.equal(m.enabled, true)
  const req = m.command('ALARM_SNOOZE')
  m.receive(message('ALARM_COMMAND_SENT', req.alarmId, { phase: 'SENT_UNVERIFIED', command: req.type }, req.requestId))
  assert.equal(m.state, 'UNVERIFIED'); assert.equal(m.enabled, false); assert.notEqual(m.phase, 'EXECUTED')
})
test('bridge accepts correlated unverified result but rejects wrong command', async () => {
  let calls = 0
  const b = new AndroidBridge({ execute: async req => { calls++; return message('ALARM_COMMAND_SENT', req.alarmId, { phase: 'SENT_UNVERIFIED', command: req.type }, req.requestId) } })
  const req = message('ALARM_DISMISS', 'a')
  const results = await Promise.all([b.execute(req), b.execute(req)])
  assert.equal(calls, 1); assert.equal(results[0].type, 'ALARM_COMMAND_SENT')
  const bad = new AndroidBridge({ execute: async r => message('ALARM_COMMAND_SENT', r.alarmId, { phase: 'SENT_UNVERIFIED', command: 'ALARM_SNOOZE' }, r.requestId) })
  assert.equal((await bad.execute(req)).payload.code, 'INVALID_RESPONSE')
  assert.equal(parse(message('ALARM_COMMAND_SENT', 'a', { phase: 'EXECUTED', command: 'ALARM_DISMISS' })), null)
})

test('forged response MAC cannot impersonate Android even with correct correlation', async () => {
  const t = new LoopbackTransport({ pairing: () => pairing, fetcher: async options => {
    const r = reply(JSON.parse(options.body)); r.body.mac = '0'.repeat(64); return r
  } })
  assert.equal((await t.refresh()).payload.androidAvailable, false)
})
