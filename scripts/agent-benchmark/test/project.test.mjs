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
})
