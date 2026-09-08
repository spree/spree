import { describe, expect, it } from 'vitest'

/**
 * The operator's packaging page is shared with the seller panel, and every
 * write on it goes through the client registered here. Registering `list`
 * alone still renders a page — the add button and row actions just vanish —
 * so a dropped method is invisible until someone tries to save.
 *
 * Asserted against the source rather than a built client because building one
 * needs a live SDK and a session; what can go wrong here is a missing line.
 */
describe('the panel client registration', () => {
  const source = new URL('./api-client-setup.ts', import.meta.url)

  async function read() {
    const { readFile } = await import('node:fs/promises')
    return readFile(source, 'utf8')
  }

  it('registers every packaging method the shared settings page calls', async () => {
    const text = await read()
    const block = text.match(/packageTypes:\s*\{[\s\S]*?\n {2}\},/)?.[0]

    expect(block, 'no packageTypes registration found').toBeTruthy()
    for (const method of ['list', 'get', 'create', 'update', 'delete']) {
      expect(block, `packageTypes.${method} is not registered`).toContain(`${method}:`)
    }
  })

  it('registers every stock-location method that page calls', async () => {
    const text = await read()
    const block = text.match(/stockLocations:\s*\{[\s\S]*?\n {2}\},/)?.[0]

    expect(block, 'no stockLocations registration found').toBeTruthy()
    for (const method of ['list', 'get', 'create', 'update']) {
      expect(block, `stockLocations.${method} is not registered`).toContain(`${method}:`)
    }
  })
})
