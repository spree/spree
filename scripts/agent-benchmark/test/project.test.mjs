import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { sh } from '../lib/project.mjs'

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
    const fs = await import('node:fs')
    const pid = Number(fs.readFileSync(pidFile, 'utf8'))
    fs.rmSync(pidFile, { force: true })
    await new Promise((resolve) => setTimeout(resolve, 600))
    // Gone, or a zombie waiting for an init that does not reap (as in some containers).
    let state = 'gone'
    try {
      state = fs.readFileSync(`/proc/${pid}/stat`, 'utf8').split(' ')[2]
    } catch {
      try {
        process.kill(pid, 0)
        state = 'alive'
      } catch {}
    }
    assert.ok(state === 'gone' || state === 'Z', `descendant is still running (${state})`)
  })
})
