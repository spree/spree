import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { NO_BODY, readBody } from '../src/api/body'

describe('readBody', () => {
  const tempFiles: string[] = []

  afterEach(() => {
    for (const file of tempFiles) fs.rmSync(file, { force: true })
    tempFiles.length = 0
  })

  it('returns the NO_BODY sentinel when no data given', async () => {
    expect(await readBody(undefined)).toBe(NO_BODY)
  })

  it('preserves a literal null body (distinct from absence)', async () => {
    expect(await readBody('null')).toBeNull()
  })

  it('parses inline JSON', async () => {
    expect(await readBody('{"name":"Tee"}')).toEqual({ name: 'Tee' })
  })

  it('gives a clear error for a missing @file', async () => {
    await expect(readBody('@/no/such/file.json')).rejects.toThrow(/Request body file not found/)
  })

  it('reads @file payloads', async () => {
    const file = path.join(os.tmpdir(), `spree-cli-body-${process.pid}.json`)
    tempFiles.push(file)
    fs.writeFileSync(file, '{"amount":25}')

    expect(await readBody(`@${file}`)).toEqual({ amount: 25 })
  })

  it('rejects invalid JSON with a clear error', async () => {
    await expect(readBody('{nope')).rejects.toThrow(/not valid JSON/)
  })
})
