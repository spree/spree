import type { DeliveryZone } from '@spree/admin-sdk'
import type { DeliveryZoneMemberValues } from '../../../schemas/delivery-zone'

/**
 * One row of the country list, whether or not the store sells there. Countries
 * outside every market only appear when the zone already claims them, so an
 * older member is never silently dropped on the next save.
 */
export interface CountryRow {
  iso: string
  name: string
  statesRequired: boolean
  /** The zone kept this country but no market covers it any more. */
  offMarket: boolean
  /** Another zone in the same profile already claims it. */
  claimed: boolean
}

/** What the member list means, expressed the way the picker manipulates it. */
export interface Selection {
  /** ISOs selected as a whole country. */
  countries: Set<string>
  /** ISO → selected state abbreviations, for partially selected countries. */
  states: Map<string, Set<string>>
  postalRules: DeliveryZoneMemberValues[]
}

export function readSelection(members: DeliveryZoneMemberValues[]): Selection {
  const countries = new Set<string>()
  const states = new Map<string, Set<string>>()
  const postalRules: DeliveryZoneMemberValues[] = []

  for (const member of members) {
    if (member.member_type === 'country' && member.country_iso) {
      countries.add(member.country_iso)
    } else if (member.member_type === 'state' && member.country_iso && member.state_abbr) {
      const forCountry = states.get(member.country_iso) ?? new Set<string>()
      forCountry.add(member.state_abbr)
      states.set(member.country_iso, forCountry)
    } else if (member.member_type === 'postal_code') {
      postalRules.push(member)
    }
  }

  return { countries, states, postalRules }
}

/**
 * Rebuilds the flat member list the API expects. Country members come first so
 * a saved zone reads top-down the same way the picker renders it.
 */
export function writeSelection(selection: Selection): DeliveryZoneMemberValues[] {
  const members: DeliveryZoneMemberValues[] = []

  for (const iso of [...selection.countries].sort()) {
    members.push({ member_type: 'country', country_iso: iso })
  }

  for (const [iso, abbrs] of [...selection.states.entries()].sort(([left], [right]) =>
    left.localeCompare(right),
  )) {
    for (const abbr of [...abbrs].sort()) {
      members.push({ member_type: 'state', country_iso: iso, state_abbr: abbr })
    }
  }

  return [...members, ...selection.postalRules]
}

/** ISOs and per-country states that sibling zones of the same profile hold. */
/**
 * Checking a country supersedes anything narrower inside it: its individual
 * states, and its postal rules. Members OR together at match time, so a whole
 * country already matches every address a narrower member could — leaving
 * those behind would persist config that can never change an outcome.
 */
export function supersedeCountry(selection: Selection, iso: string): Selection {
  const countries = new Set(selection.countries)
  const states = new Map(selection.states)

  countries.add(iso)
  states.delete(iso)

  return {
    countries,
    states,
    postalRules: selection.postalRules.filter((rule) => rule.country_iso !== iso),
  }
}

export function claimedByOtherZones(siblingZones: DeliveryZone[]) {
  const countries = new Set<string>()
  const states = new Map<string, Set<string>>()

  for (const zone of siblingZones) {
    for (const member of zone.members ?? []) {
      if (!member.country_iso) continue
      if (member.member_type === 'country') {
        countries.add(member.country_iso)
      } else if (member.member_type === 'state' && member.state_abbr) {
        const forCountry = states.get(member.country_iso) ?? new Set<string>()
        forCountry.add(member.state_abbr)
        states.set(member.country_iso, forCountry)
      }
    }
  }

  return { countries, states }
}
