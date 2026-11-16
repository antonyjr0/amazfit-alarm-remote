import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import { AlarmMachine } from '../shared/alarm-machine.js'
import { AndroidBridge } from '../shared/android-bridge.js'
import { message, parse } from '../shared/protocol.js'

const source = path => readFileSync(new URL(path, import.meta.url), 'utf8').replace(/^import .*$/gm, '')
const flush = () => new Promise(resolve => setImmediate(resolve))
function device(request) {
  let page
  const widgets = []
  const timers = new Map(); let serial = 0
  const context = {
    Page: p => { page = p }, BasePage: p => p, AlarmMachine, console: { log() {} },
    connectStatus: () => true, getDeviceInfo: () => ({ width: 466 }),
    setInterval: fn => { timers.set(++serial, fn); return serial }, clearInterval: id => timers.delete(id),
    setTimeout: fn => { timers.set(++serial, fn); return serial }, clearTimeout: id => timers.delete(id),
    ui: { widget: { TEXT: 'text', BUTTON: 'button' }, prop: { TEXT: 'text', MORE: 'more' }, align: {}, text_style: {},
      createWidget(type, props) { const w = { type, props, setProperty(k, v) { if (k === 'more') Object.assign(this.props, v); else this.props[k] = v } }; widgets.push(w); return w } }
  }
  vm.runInNewContext(source('../page/index.js'), context)
  page.request = request; page.onInit(); page.build()
  return { page, widgets, timers }
}
test('device buttons are guarded; exact command is sent and only execution confirms', async () => {
  let resolveCommand; const requests = []
  const { page, widgets, timers } = device(req => {
    requests.push(req)
    return req.method === 'alarm.status'
      ? Promise.resolve(message('CONNECTION_STATUS', null, { connected: true, androidAvailable: true }))
      : new Promise(resolve => { resolveCommand = resolve })
  })
  const buttons = widgets.filter(w => w.type === 'button')
  buttons[0].props.click_func(); assert.equal(requests.length, 1)
  await flush()
  page.onCall({ method: 'alarm.event', params: message('ALARM_RINGING', 'a', { time: '06:45' }) })
  assert.equal(widgets[2].props.text, 'Sveglia in corso')
  buttons[1].props.click_func(); buttons[1].props.click_func()
  assert.equal(requests.length, 2); assert.equal(requests[1].params.type, 'ALARM_SNOOZE')
  assert.equal(page.machine.state, 'WAITING_CONFIRMATION')
  const req = requests[1].params
  resolveCommand(message('ALARM_SNOOZED', 'a', { phase: 'EXECUTED' }, req.requestId)); await flush()
  assert.equal(widgets[2].props.text, 'Sveglia posticipata')
  page.onDestroy(); assert.equal(timers.size, 0)
})
test('device ignores malformed late response after a replacement alarm', async () => {
  let resolveCommand
  const { page } = device(req => req.method === 'alarm.status'
    ? Promise.resolve(message('CONNECTION_STATUS', null, { connected: true, androidAvailable: true }))
    : new Promise(resolve => { resolveCommand = resolve }))
  await flush()
  page.onCall({ method: 'alarm.event', params: message('ALARM_RINGING', 'a', {}) })
  page.sendCommand('ALARM_DISMISS')
  page.onCall({ method: 'alarm.event', params: message('ALARM_RINGING', 'b', {}) })
  resolveCommand({}); await flush(); assert.equal(page.machine.state, 'RINGING'); assert.equal(page.machine.alarm.alarmId, 'b')
  page.onBleChanged(false); assert.equal(page.machine.state, 'DISCONNECTED'); page.onDestroy()
})
test('device releases timers even when closed during a pending heartbeat', () => {
  const { page, timers } = device(() => new Promise(() => {}))
  page.onDestroy(); assert.equal(timers.size, 0)
})
test('app-side responds truthfully with Android unavailable and rejects malformed requests', async () => {
  let side; const storage = new Map()
  vm.runInNewContext(source('../app-side/index.js'), {
    BaseSideService: p => p, AppSideService: p => { side = p }, AndroidBridge, parse,
    settings: { settingsStorage: { setItem: (k, v) => storage.set(k, v) } }, console: { log() {} }
  })
  side.onInit()
  let response
  side.onRequest({ method: 'alarm.status' }, (err, data) => { response = data })
  assert.equal(response.payload.androidAvailable, false)
  side.onRequest({ method: 'alarm.command', params: message('ALARM_DISMISS', 'a') }, (err, data) => { response = data })
  await flush(); assert.equal(response.payload.code, 'NOT_CONFIGURED')
  side.onRequest({ method: 'alarm.command', params: {} }, err => { response = err })
  await flush(); assert.equal(response, 'INVALID_REQUEST'); assert.ok(storage.has('diagnostics')); side.onDestroy()
})
test('settings preference survives rebuild using official storage interface', () => {
  let config; const storage = new Map(); let toggle
  vm.runInNewContext(source('../setting/index.js'), {
    AppSettingsPage: p => { config = p }, Section: (p, children) => children,
    Text: (p, text) => text, Toggle: p => { toggle = p; return p }
  })
  const settingsStorage = { getItem: k => storage.get(k), setItem: (k, v) => storage.set(k, v) }
  config.build({ settingsStorage }); assert.equal(toggle.value, true)
  toggle.onChange(false); config.build({ settingsStorage }); assert.equal(toggle.value, false)
})
