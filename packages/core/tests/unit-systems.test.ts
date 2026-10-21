import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import { parse } from 'yaml'
import { UNIT_SYSTEM_WEIGHT_UNITS, UNIT_SYSTEMS, WeightUnit } from '../src'

// Every `unit_system` the Admin API reference declares, wherever it appears.
function publishedUnitSystems(node: unknown, found = new Set<string>()): Set<string> {
  if (Array.isArray(node)) {
    for (const item of node) publishedUnitSystems(item, found)
  } else if (node && typeof node === 'object') {
    for (const [key, value] of Object.entries(node)) {
      const values = (value as { enum?: unknown })?.enum
      if (key === 'unit_system' && Array.isArray(values)) {
        for (const system of values) found.add(String(system))
      }
      publishedUnitSystems(value, found)
    }
  }
  return found
}

describe('unit systems', () => {
  it('match the unit systems the Admin API accepts', () => {
    const reference = parse(
      readFileSync(resolve(__dirname, '../../../docs/api-reference/admin.yaml'), 'utf-8'),
    )
    expect([...publishedUnitSystems(reference)].sort()).toEqual([...UNIT_SYSTEMS].sort())
  })

  it('offer every weight unit in exactly one system', () => {
    expect(Object.values(UNIT_SYSTEM_WEIGHT_UNITS).flat().sort()).toEqual(
      Object.values(WeightUnit).sort(),
    )
  })
})
