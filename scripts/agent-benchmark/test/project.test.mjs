import assert from 'node:assert/strict'
import fs from 'node:fs'
import { describe, it } from 'node:test'
import { sh } from '../lib/project.mjs'

// The /proc state of a process ('Z' for a zombie), 'gone' only when the
// kernel says no such process (ESRCH), 'alive' when it exists but /proc is
// unavailable, and the error code when the probe itself fails.
function processState(pid) {
  try {
    return fs.readFileSync(`/proc/${pid}/stat`, 'utf8').split(' ')[2]
  } catch {}
  try {
    process.kill(pid, 0)
    return 'alive'
  } catch (error) {
    return error.code === 'ESRCH' ? 'gone' : `probe failed: ${error.code}`
  }
}

describe('sh', () => {
  it('returns the exit code and output', async () => {
    const result = await sh('sh', ['-c', 'echo hi; exit 3'])
    assert.equal(result.code, 3)
    assert.equal(result.stdout, 'hi\n')
    assert.equal(result.timedOut, false)
  })

  it('kills a process group that ignores SIGTERM, and records the timeout', {
    skip: process.platform === 'win32',
  }, async () => {
    const started = Date.now()
    const result = await sh('sh', ['-c', 'trap "" TERM; sleep 30 & sleep 30; wait'], {
      timeoutMs: 200,
      graceMs: 200,
    })
    assert.equal(result.timedOut, true)
    assert.equal(result.signal, 'SIGKILL')
    assert.ok(Date.now() - started < 5000)
  })

  it('still kills a descendant that ignores SIGTERM after the leader exits', {
    skip: process.platform === 'win32',
  }, async () => {
    const pidFile = `/tmp/sh-test-${process.pid}-${Date.now()}`
    // The leader exits on SIGTERM; its child ignores SIGTERM and closes its pipes.
    const result = await sh(
      'sh',
      ['-c', `(trap "" TERM; exec >/dev/null 2>&1; sleep 30) & echo $! > ${pidFile}; sleep 30`],
      { timeoutMs: 200, graceMs: 200 },
    )
    assert.equal(result.timedOut, true)
    const pid = Number(fs.readFileSync(pidFile, 'utf8'))
    fs.rmSync(pidFile, { force: true })
    await new Promise((resolve) => setTimeout(resolve, 600))
    // Gone, or a zombie waiting for an init that does not reap (as in some containers).
    const state = processState(pid)
    assert.ok(state === 'gone' || state === 'Z', `descendant is still running (${state})`)
  })

  it('kills a surviving descendant even when nothing else keeps Node running', {
    skip: process.platform === 'win32',
  }, async () => {
    const pidFile = `/tmp/sh-test-${process.pid}-${Date.now()}-alone`
    const lib = new URL('../lib/project.mjs', import.meta.url).href
    // A separate Node process that exits as soon as nothing holds it open.
    const script = `
      const { sh } = await import(${JSON.stringify(lib)})
      await sh('sh', ['-c', '(trap "" TERM; exec >/dev/null 2>&1; sleep 30) & echo $! > ${pidFile}; sleep 30'], { timeoutMs: 200, graceMs: 200 })
    `
    const node = await sh(process.execPath, ['--input-type=module', '-e', script], {
      timeoutMs: 10_000,
    })
    assert.equal(node.code, 0, node.stderr)
    const pid = Number(fs.readFileSync(pidFile, 'utf8'))
    fs.rmSync(pidFile, { force: true })
    await new Promise((resolve) => setTimeout(resolve, 300))
    const state = processState(pid)
    if (state !== 'gone' && state !== 'Z') {
      try {
        process.kill(pid, 'SIGKILL')
      } catch {}
    }
    assert.ok(state === 'gone' || state === 'Z', `descendant outlived Node (${state})`)
  })

  it('keeps the exit status of a leader that exited while a process outside the group held the pipes', {
    skip: process.platform !== 'linux',
  }, async () => {
    // The leader exits cleanly on SIGTERM; a setsid process keeps stdout open.
    const result = await sh(
      'sh',
      ['-c', 'trap "exit 0" TERM; setsid sleep 3 & while :; do sleep 0.05; done'],
      { timeoutMs: 200, graceMs: 200 },
    )
    assert.equal(result.timedOut, true)
    assert.equal(result.code, 0)
    assert.equal(result.signal, null)
  })
})
