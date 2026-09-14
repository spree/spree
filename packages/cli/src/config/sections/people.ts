import type { CustomerEntry, SellerEntry } from '../schema.js'
import type { LiveRecord } from '../types.js'
import { keysOf, type Payload, pick, present, refs, type Section } from './section.js'

const CUSTOMER_ATTRIBUTES: (keyof CustomerEntry)[] = [
  'email',
  'first_name',
  'last_name',
  'phone',
  'accepts_email_marketing',
  'tags',
]

export const customers: Section<CustomerEntry> = {
  name: 'customers',
  scope: 'write_customers',
  introspectByDefault: false,
  path: '/customers',
  keyAttribute: 'email',
  filterable: true,
  liveKey: (live) => String(live.email),
  fileKeys: (config) => (config.customers ?? []).map((customer) => customer.email),
  entries: (config) => config.customers ?? [],
  entryKey: (entry) => entry.email,
  references: (config) => ({
    customer_groups: (config.customers ?? []).flatMap((customer) => customer.customer_groups ?? []),
  }),
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, CUSTOMER_ATTRIBUTES)
    const groups = await refs(ctx, 'customer_groups', entry.customer_groups, path)
    if (groups) payload.customer_group_ids = groups
    return payload
  },
  async current(live) {
    return live
  },
  // The password is set on create only: the file cannot read it back, so it
  // cannot tell whether the live one differs.
  async create(payload, entry, ctx) {
    const body = entry.password
      ? { ...payload, password: entry.password, password_confirmation: entry.password }
      : payload
    return ctx.client.request<LiveRecord>('POST', '/customers', { body })
  },
  async toFile(live, ctx) {
    const entry: CustomerEntry = present(
      live as unknown as CustomerEntry,
      CUSTOMER_ATTRIBUTES,
    ) as CustomerEntry
    if (entry.accepts_email_marketing === false) delete entry.accepts_email_marketing
    const groups = await keysOf(ctx, 'customer_groups', live.customer_group_ids)
    if (groups.length) entry.customer_groups = groups
    return entry
  },
}

const SELLER_ATTRIBUTES: (keyof SellerEntry)[] = [
  'slug',
  'name',
  'contact_email',
  'billing_email',
  'legal_name',
  'registration_number',
  'tax_remittance',
]

const STATUS_ACTIONS: Record<string, string> = { approved: 'approve', suspended: 'suspend' }

export const sellers: Section<SellerEntry> = {
  name: 'sellers',
  scope: 'write_sellers',
  introspectByDefault: true,
  path: '/sellers',
  keyAttribute: 'slug',
  filterable: true,
  liveKey: (live) => String(live.slug),
  fileKeys: (config) => (config.sellers ?? []).map((seller) => seller.slug),
  entries: (config) => config.sellers ?? [],
  entryKey: (entry) => entry.slug,
  async desired(entry) {
    // `status` is not writable: it moves through the approve/suspend actions in afterWrite.
    return { ...pick(entry, SELLER_ATTRIBUTES), ...(entry.status ? { status: entry.status } : {}) }
  },
  async current(live) {
    return live
  },
  async create(payload, _entry, ctx) {
    const { status: _status, ...body } = payload
    return ctx.client.request<LiveRecord>('POST', '/sellers', { body })
  },
  async update(live, payload, _entry, ctx) {
    const { status: _status, ...body } = payload
    return ctx.client.request<LiveRecord>('PATCH', `/sellers/${live.id}`, { body })
  },
  // Approval steps over the onboarding checklist the way an operator can:
  // the file is the operator's word that the seller may trade.
  async afterWrite(entry, live, _changes, ctx) {
    if (!entry.status || live.status === entry.status) return
    const action = STATUS_ACTIONS[entry.status]
    const body = action === 'approve' ? { override_requirements: true } : {}
    await ctx.client.request('PATCH', `/sellers/${live.id}/${action}`, { body })
  },
  async toFile(live) {
    const entry = present(live as unknown as SellerEntry, SELLER_ATTRIBUTES) as SellerEntry
    if (live.status === 'approved' || live.status === 'suspended') entry.status = live.status
    return entry
  },
}
