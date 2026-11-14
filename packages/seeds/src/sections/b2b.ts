import type {
  Catalog as SdkCatalog,
  Company as SdkCompany,
  PriceList as SdkPriceList,
} from '@spree/admin-sdk'
import { listAll } from '../client.js'
import {
  CATALOG_ATTRIBUTES,
  type CatalogEntry,
  COMPANY_ATTRIBUTES,
  type CompanyEntry,
  PRICE_LIST_ATTRIBUTES,
  type PriceListEntry,
} from '../schema.js'
import type { LiveRecord } from '../types.js'
import { desiredMembers, liveMembers, membersToFile, syncMembers } from './membership.js'
import { comparableRules, desiredRules, rulesToFile, wireRules, withLiveIds } from './rules.js'
import { type Payload, pick, present, type Section } from './section.js'

type Company = SdkCompany & LiveRecord
type PriceList = SdkPriceList & LiveRecord
type Catalog = SdkCatalog & LiveRecord

// --- Companies ---------------------------------------------------------------

interface Membership extends LiveRecord {
  email?: string | null
}

const memberEmails = async (ctx: Parameters<Section['desired']>[1], live: LiveRecord) =>
  (await listAll<Membership>(ctx.client, `/companies/${live.id}/memberships`)).map((membership) =>
    String(membership.email ?? '').toLowerCase(),
  )

export const companies: Section<CompanyEntry, Company> = {
  name: 'companies',
  scope: 'write_customers',
  pruneRefusal:
    'a company carries orders, addresses and tax records; remove one from the dashboard',
  introspectByDefault: false,
  // A division names its parent, so parents are written first.
  sequential: true,
  path: '/companies',
  keyAttribute: 'name',
  filterable: true,
  entries: (config) => {
    const all = config.companies ?? []
    const depth = (entry: CompanyEntry, seen = 0): number => {
      const parent = entry.parent && all.find((candidate) => candidate.name === entry.parent)
      return parent && seen < all.length ? 1 + depth(parent, seen + 1) : 0
    }
    return [...all].sort((left, right) => depth(left) - depth(right))
  },
  entryKey: (entry) => entry.name,
  references: (config) => ({
    customers: (config.companies ?? []).flatMap((company) => company.members ?? []),
  }),
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, COMPANY_ATTRIBUTES)
    if (entry.parent) payload.parent_id = await ctx.ref('companies', entry.parent, path)
    if (entry.members) {
      // Membership is granted to customers that exist; an unknown email
      // would become an invitation, which a file has no business sending.
      await Promise.all(entry.members.map((email) => ctx.ref('customers', email, path)))
      payload.members = [...entry.members].sort()
    }
    return payload
  },
  // Only the listed members are compared: the rest were added elsewhere and stay.
  async current(live, ctx, desired) {
    if (!desired.members) return live
    const emails = await memberEmails(ctx, live)
    return {
      ...live,
      members: (desired.members as string[]).filter((email) => emails.includes(email)),
    }
  },
  async create(payload, _entry, ctx) {
    const { members: _members, ...body } = payload
    return ctx.client.request<Company>('POST', '/companies', { body })
  },
  async update(live, payload, _entry, ctx) {
    const { members: _members, ...body } = payload
    return ctx.client.request<Company>('PATCH', `/companies/${live.id}`, { body })
  },
  async afterWrite(entry, live, _changes, ctx) {
    if (!entry.members) return
    const emails = await memberEmails(ctx, live)
    for (const email of entry.members.filter((candidate) => !emails.includes(candidate))) {
      await ctx.client.request('POST', `/companies/${live.id}/memberships`, {
        body: { customer_email: email },
      })
    }
  },
  async toFile(live, ctx) {
    const parent = live.parent_id ? await ctx.keyOf('companies', String(live.parent_id)) : null
    const members = (await memberEmails(ctx, live)).filter(Boolean).sort()
    const entry = present(live as unknown as CompanyEntry, COMPANY_ATTRIBUTES) as CompanyEntry
    if (entry.po_number_required === false) delete entry.po_number_required
    return {
      ...entry,
      ...(parent ? { parent } : {}),
      ...(members.length ? { members } : {}),
    }
  },
}

// --- Price lists -------------------------------------------------------------

const PRICE_RULE_TYPES = '/price_lists/price_rule_types'

const isActive = (live: LiveRecord) => live.status === 'active' || live.status === 'scheduled'

/**
 * A price list's terms: who it applies to and when. Its prices are rows per
 * variant, which come from the price-list CSV import or the dashboard.
 */
export const priceLists: Section<PriceListEntry, PriceList> = {
  name: 'price_lists',
  scope: 'write_products',
  introspectByDefault: true,
  path: '/price_lists',
  keyAttribute: 'name',
  filterable: true,
  // A catalog's own list is written with its catalog, never on its own.
  listParams: { 'q[catalog_id_null]': 1 },
  expand: ['price_rules'],
  entries: (config) => config.price_lists ?? [],
  entryKey: (entry) => entry.name,
  async desired(entry, ctx, path) {
    return {
      ...pick(entry, PRICE_LIST_ATTRIBUTES),
      ...(entry.active !== undefined ? { active: entry.active } : {}),
      ...(entry.rules
        ? { rules: await desiredRules(entry.rules, PRICE_RULE_TYPES, ctx, path) }
        : {}),
    }
  },
  async current(live, _ctx, desired) {
    return {
      ...live,
      active: isActive(live),
      ...(desired.rules ? { rules: comparableRules(live.price_rules) } : {}),
    }
  },
  async wire(payload, ctx) {
    return payload.rules
      ? { ...payload, rules: await wireRules(payload.rules, PRICE_RULE_TYPES, ctx) }
      : payload
  },
  async create(payload, _entry, ctx) {
    const { active: _active, ...body } = payload
    return ctx.client.request<PriceList>('POST', '/price_lists', { body })
  },
  async update(live, payload, _entry, ctx) {
    const { active: _active, ...body } = payload
    return ctx.client.request<PriceList>('PATCH', `/price_lists/${live.id}`, {
      body: {
        ...body,
        ...(body.rules ? { rules: withLiveIds(body.rules, live.price_rules) } : {}),
      },
    })
  },
  // The status moves through its own actions, which also settle scheduling.
  async afterWrite(entry, live, _changes, ctx) {
    if (entry.active === undefined || entry.active === isActive(live)) return
    await ctx.client.request(
      'PATCH',
      `/price_lists/${live.id}/${entry.active ? 'activate' : 'deactivate'}`,
    )
  },
  async toFile(live, ctx) {
    const rules = await rulesToFile(
      live.price_rules as Parameters<typeof rulesToFile>[0],
      PRICE_RULE_TYPES,
      ctx,
    )
    const entry = present(
      live as unknown as PriceListEntry,
      PRICE_LIST_ATTRIBUTES,
    ) as PriceListEntry
    if (entry.match_policy === 'all') delete entry.match_policy
    return {
      ...entry,
      ...(isActive(live) ? { active: true } : {}),
      ...(rules.length ? { rules } : {}),
    }
  },
}

// --- Catalogs ----------------------------------------------------------------

interface Assignment {
  assignable_type: string
  assignable_id: string
  assignable_name?: string | null
}

const AUDIENCES = [
  ['company', 'companies'],
  ['customer_group', 'customer_groups'],
] as const

const byAudience = (left: [string, string], right: [string, string]) =>
  left[0].localeCompare(right[0]) || left[1].localeCompare(right[1])

/** A catalog: an assortment, and the companies and customer groups it is offered to. */
export const catalogs: Section<CatalogEntry, Catalog> = {
  name: 'catalogs',
  scope: 'write_products',
  introspectByDefault: true,
  path: '/catalogs',
  keyAttribute: 'name',
  filterable: true,
  expand: ['assignments'],
  entries: (config) => config.catalogs ?? [],
  entryKey: (entry) => entry.name,
  references: (config) => {
    const all = config.catalogs ?? []
    return {
      companies: all.flatMap((catalog) => catalog.companies ?? []),
      customer_groups: all.flatMap((catalog) => catalog.customer_groups ?? []),
      products: all.flatMap((catalog) => catalog.products ?? []),
    }
  },
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, CATALOG_ATTRIBUTES)
    if (entry.companies || entry.customer_groups) {
      // In one order on both sides of the comparison: by kind, then by name.
      const audience = AUDIENCES.flatMap(([type, section]) =>
        (entry[section] ?? []).map((name): [string, string] => [type, name]),
      ).sort(byAudience)
      payload.assignments = await Promise.all(
        audience.map(async ([type, name]) => ({
          assignable_type: type,
          assignable_id: await ctx.ref(
            `${type === 'company' ? 'companies' : 'customer_groups'}`,
            name,
            path,
          ),
        })),
      )
    }
    return { ...payload, ...(await desiredMembers(entry.products, ctx, path)) }
  },
  async current(live, ctx, desired) {
    const assignments = (live.assignments as Assignment[] | undefined) ?? []
    return {
      ...live,
      ...(desired.assignments
        ? {
            assignments: [...assignments]
              .sort((left, right) =>
                byAudience(
                  [left.assignable_type, left.assignable_name ?? ''],
                  [right.assignable_type, right.assignable_name ?? ''],
                ),
              )
              .map((assignment) => ({
                assignable_type: assignment.assignable_type,
                assignable_id: assignment.assignable_id,
              })),
          }
        : {}),
      ...(await liveMembers(ctx, '/catalogs', live, desired)),
    }
  },
  async create(payload, _entry, ctx) {
    const { products: _products, ...body } = payload
    return ctx.client.request<Catalog>('POST', '/catalogs', { body })
  },
  async update(live, payload, _entry, ctx) {
    const { products: _products, ...body } = payload
    return ctx.client.request<Catalog>('PATCH', `/catalogs/${live.id}`, { body })
  },
  afterWrite: (entry, live, _changes, ctx) => syncMembers(ctx, '/catalogs', live, entry.products),
  async toFile(live, ctx) {
    const assignments = (live.assignments as Assignment[] | undefined) ?? []
    const named = (type: string) =>
      assignments
        .filter((assignment) => assignment.assignable_type === type && assignment.assignable_name)
        .map((assignment) => String(assignment.assignable_name))
        .sort()
    const entry = present(live as unknown as CatalogEntry, CATALOG_ATTRIBUTES) as CatalogEntry
    // A new catalog is inactive until it is switched on.
    if (entry.active === false) delete entry.active
    const companyNames = named('company')
    const groupNames = named('customer_group')
    return {
      ...entry,
      ...(companyNames.length ? { companies: companyNames } : {}),
      ...(groupNames.length ? { customer_groups: groupNames } : {}),
      ...(await membersToFile(ctx, '/catalogs', live)),
    }
  },
}
