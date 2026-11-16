// Integration smoke: real JS HTTP client -> real Dart loopback server -> native stub.
import { spawn } from 'node:child_process'
import { createInterface } from 'node:readline'
import assert from 'node:assert/strict'
import { LoopbackTransport } from '../amazfit-alarm-remote/shared/loopback-transport.js'
import { AndroidBridge } from '../amazfit-alarm-remote/shared/android-bridge.js'
import { message } from '../amazfit-alarm-remote/shared/protocol.js'
const child = spawn(process.env.DART || 'dart', ['--packages=' + new URL('../android_alarm_remote/.dart_tool/package_config.json', import.meta.url).pathname, new URL('./loopback_fixture.dart', import.meta.url).pathname], { stdio: ['pipe', 'pipe', 'pipe'] })
const lines = [], errors = []
child.stderr.on('data', c => errors.push(c.toString()))
let timer
try {
  const pairing = await Promise.race([
    new Promise((resolve, reject) => {
      const reader = createInterface({ input: child.stdout })
      reader.on('line', line => { if (/^\d+:[A-Za-z0-9_-]{43}$/.test(line)) resolve(line); else lines.push(line) })
      child.on('error', reject); child.on('exit', code => reject(new Error(`fixture exit ${code}`)))
    }), new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('fixture timeout')), 15000) })
  ])
  const transport = new LoopbackTransport({ pairing: () => pairing, fetcher: async options => {
    const response = await fetch(options.url, { method: options.method, headers: options.headers, body: options.body })
    return { status: response.status, body: await response.text() }
  } })
  const status = await transport.refresh()
  assert.equal(status.payload.candidate.armed, true)
  const b = new AndroidBridge(transport), req = message('ALARM_DISMISS', 'fixture-alarm')
  const [one, duplicate] = await Promise.all([b.execute(req), b.execute(req)])
  assert.equal(one.type, 'ALARM_COMMAND_SENT'); assert.equal(one.payload.phase, 'SENT_UNVERIFIED')
  assert.deepEqual(one, duplicate)
  // Bypass JS dedup: Dart must also return the original result, without replay.
  assert.equal((await transport.execute(req)).type, 'ALARM_COMMAND_SENT')
  assert.equal((await transport.execute(message('ALARM_SNOOZE', 'fixture-alarm'))).type, 'ERROR')
  await new Promise(r => setImmediate(r)); assert.deepEqual(lines, ['native-stub:1'])
  console.log('PASS JS -> HTTP -> Dart, correlated status and command, duplicates execute native stub once; no hardware claim.')
} catch (e) { console.error(e.message, errors.join('')); process.exitCode = 1 }
finally { clearTimeout(timer); child.stdin.end('stop\n'); child.kill() }
