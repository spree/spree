import type { DeliveryZone, DeliveryZoneMember } from '@spree/admin-sdk'
import { describe, expect, it } from 'vitest'
import type { DeliveryZoneMemberValues } from '../../../schemas/delivery-zone'
import {
  claimedByOtherZones,
  readSelection,
  supersedeCountry,
  writeSelection,
} from './delivery-zone-selection'

/** Only the member fields the claim computation reads have to be real. */
function zone(members: Partial<DeliveryZoneMember>[]): DeliveryZone {
  return { members } as DeliveryZone
}

describe('readSelection', () => {
  it('splits members into whole countries, states and postal rules', () => {
    const selection = readSelection([
      { member_type: 'country', country_code: 'DE' },
      { member_type: 'state', country_code: 'US', state_code: 'CA' },
      { member_type: 'state', country_code: 'US', state_code: 'NY' },
      { member_type: 'postal_code', country_code: 'FR', postal_code_prefix: '75' },
    ])

    expect([...selection.countries]).toEqual(['DE'])
    expect([...(selection.states.get('US') ?? [])]).toEqual(['CA', 'NY'])
    expect(selection.postalRules).toHaveLength(1)
  })

  it('ignores members missing the fields that give them meaning', () => {
    const selection = readSelection([
      { member_type: 'country', country_code: '' },
      { member_type: 'state', country_code: 'US', state_code: '' },
    ])

    expect(selection.countries.size).toBe(0)
    expect(selection.states.size).toBe(0)
  })
})

describe('writeSelection', () => {
  it('round-trips a selection back into the flat member list', () => {
    const members: DeliveryZoneMemberValues[] = [
      { member_type: 'country', country_code: 'DE' },
      { member_type: 'state', country_code: 'US', state_code: 'CA' },
      { member_type: 'postal_code', country_code: 'FR', postal_code_prefix: '75' },
    ]

    expect(writeSelection(readSelection(members))).toEqual(members)
  })

  it('orders countries before states and keeps postal rules last', () => {
    const members = writeSelection({
      countries: new Set(['US', 'DE']),
      states: new Map([['CA', new Set(['ON'])]]),
      postalRules: [{ member_type: 'postal_code', country_code: 'FR', postal_code_prefix: '75' }],
    })

    expect(members.map((member) => member.member_type)).toEqual([
      'country',
      'country',
      'state',
      'postal_code',
    ])
    // Countries are emitted in ISO order so a saved zone reads consistently.
    expect(members[0].country_code).toBe('DE')
    expect(members[1].country_code).toBe('US')
  })
})

describe('supersedeCountry', () => {
  it('drops the states and postal rules a whole country makes redundant', () => {
    const selection = readSelection([
      { member_type: 'state', country_code: 'US', state_code: 'NY' },
      { member_type: 'postal_code', country_code: 'US', postal_code_prefix: '10' },
      { member_type: 'postal_code', country_code: 'DE', postal_code_prefix: '10' },
    ])

    const next = supersedeCountry(selection, 'US')

    expect([...next.countries]).toEqual(['US'])
    expect(next.states.has('US')).toBe(false)
    // Germany's rule is untouched — only the superseded country is cleaned up.
    expect(next.postalRules.map((rule: DeliveryZoneMemberValues) => rule.country_code)).toEqual([
      'DE',
    ])
  })
})

describe('claimedByOtherZones', () => {
  it('collects the countries and states sibling zones already cover', () => {
    const claimed = claimedByOtherZones([
      zone([
        { member_type: 'country', country_code: 'DE' },
        { member_type: 'state', country_code: 'US', state_code: 'CA' },
      ]),
      zone([{ member_type: 'country', country_code: 'FR' }]),
    ])

    expect([...claimed.countries].sort()).toEqual(['DE', 'FR'])
    expect([...(claimed.states.get('US') ?? [])]).toEqual(['CA'])
  })

  it('treats a zone with no expanded members as claiming nothing', () => {
    expect(claimedByOtherZones([{} as DeliveryZone]).countries.size).toBe(0)
  })
})
