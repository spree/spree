import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { afterEach, describe, expect, it } from 'vitest'
import {
  ConfigValidationError,
  deployConfig,
  introspect,
  loadConfig,
  loadExtensions,
  missingScopes,
  parseConfig,
  planConfig,
  planOperations,
  registerSection,
  SECTION_NAMES,
} from '../src/node'
import { unregisterSection } from '../src/sections/index'
import { FakeApi } from './fake-api'
import loyaltyTiers from './fixtures/loyalty-extension'

const FILE = path.join(path.dirname(fileURLToPath(import.meta.url)), 'fixtures/loyalty.yml')

const issuesOf = (run: () => unknown) => {
  try {
    run()
  } catch (error) {
    if (error instanceof ConfigValidationError) return error.issues
    throw error
  }
  return []
}

afterEach(() => unregisterSection('loyalty_tiers'))

describe('sections registered by an extension', () => {
  it('refuses a section nothing registered', () => {
    const issues = issuesOf(() => parseConfig('version: 1\nloyalty_tiers:\n  - code: gold\n'))
    expect(issues[0].message).toContain('loyalty_tiers')
  })

  it('loads the modules the file lists and deploys their sections after the built-in ones', async () => {
    expect(await loadExtensions(FILE)).toEqual(['loyalty_tiers'])
    expect(SECTION_NAMES).toContain('loyalty_tiers')

    const { config, sections } = loadConfig(FILE)
    expect(sections).toEqual(['customer_groups', 'loyalty_tiers'])

    const api = new FakeApi()
    await deployConfig(config, api)
    const group = api.all('/customer_groups')[0]
    expect(api.all('/loyalty_tiers')).toMatchObject([
      { code: 'gold', name: 'Gold', points: 500, customer_group_id: group.id },
      // The extension's schema filled in its own default.
      { code: 'silver', points: 0 },
    ])

    const again = await planConfig(config, api)
    expect(planOperations(again).map((operation) => operation.kind)).toEqual([
      'unchanged',
      'unchanged',
      'unchanged',
    ])
  })

  it('reports an entry its schema refuses, with the path and the line', () => {
    registerSection(loyaltyTiers)
    const issues = issuesOf(() =>
      parseConfig('version: 1\nloyalty_tiers:\n  - code: gold\n    points: many\n'),
    )
    expect(issues).toHaveLength(1)
    expect(issues[0]).toMatchObject({ path: 'loyalty_tiers[0].points', line: 4 })
  })

  it('needs the scope the section names, and reads the section back', async () => {
    registerSection(loyaltyTiers)
    const { config } = parseConfig('version: 1\nloyalty_tiers:\n  - code: gold\n')
    const api = new FakeApi()
    api.scopes = ['write_settings']
    expect(await missingScopes(api, config)).toEqual(['write_loyalty', 'read_loyalty'])

    api.seed('/loyalty_tiers', [{ code: 'gold', name: 'Gold', points: 500 }])
    const live = (await introspect(api, { include: ['loyalty_tiers' as never] })) as Record<
      string,
      unknown
    >
    expect(live.loyalty_tiers).toEqual([{ code: 'gold', name: 'Gold', points: 500 }])
  })

  it('refuses a name the file already uses', () => {
    expect(() => registerSection({ ...loyaltyTiers, name: 'products' as never })).toThrow(
      'already has a "products" section',
    )
    registerSection(loyaltyTiers)
    // The same definition twice is one registration.
    registerSection(loyaltyTiers)
    expect(() => registerSection({ ...loyaltyTiers })).toThrow('already has a "loyalty_tiers"')
  })

  it('names the module it could not load, and leaves a missing file to loadConfig', async () => {
    const broken = path.join(path.dirname(FILE), 'broken-extension.yml')
    await expect(loadExtensions(broken)).rejects.toThrow(
      'extensions[0]: could not load "./nowhere.js"',
    )
    await expect(loadExtensions(path.join(path.dirname(FILE), 'absent.yml'))).resolves.toEqual([])
  })
})
