import { describe, expect, it } from 'vitest'
import { RunError, run } from '../src/lib/run'

const node = (code: string) => ['-e', code]

describe('run', () => {
  it('returns stdout without its final newline', async () => {
    const result = await run(process.execPath, node('console.log("hello")'))
    expect(result).toEqual({ stdout: 'hello', stderr: '', exitCode: 0 })
  })

  it('throws a RunError carrying the exit code and output', async () => {
    const failure = run(process.execPath, node('console.error("boom"); process.exit(3)'))
    await expect(failure).rejects.toBeInstanceOf(RunError)
    await expect(failure).rejects.toMatchObject({ exitCode: 3, stderr: 'boom' })
    await expect(failure).rejects.toThrow(/exit code 3[\s\S]*boom/)
  })

  it('resolves with the exit code when reject is false', async () => {
    const result = await run(process.execPath, node('process.exit(2)'), { reject: false })
    expect(result.exitCode).toBe(2)
  })

  it('keeps stderr for the error while printing it live', async () => {
    const failure = run(process.execPath, node('console.error("live"); process.exit(1)'), {
      stdout: 'ignore',
      stderr: ['pipe', 'inherit'],
    })
    await expect(failure).rejects.toMatchObject({ stderr: 'live' })
  })

  it('passes arguments through without a shell', async () => {
    const result = await run(process.execPath, [
      '-e',
      'console.log(process.argv[1])',
      'a "quoted" & piped | arg',
    ])
    expect(result.stdout).toBe('a "quoted" & piped | arg')
  })

  it('surfaces a missing command as ENOENT', async () => {
    await expect(run('spree-command-that-does-not-exist')).rejects.toMatchObject({ code: 'ENOENT' })
  })
})
