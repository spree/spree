import type { ConfigClient, RequestOptions } from '../src/types'

type Record_ = Record<string, unknown> & { id: string }

/**
 * An in-memory stand-in for the Admin API: paginated lists with `_in`
 * filters, the store singleton, creates, updates, deletes and the handful of
 * action endpoints the engine calls. Enough to plan and apply against.
 */
export class FakeApi implements ConfigClient {
  readonly collections = new Map<string, Record_[]>()
  store: Record_ = { id: 'store_1', name: 'Shop', guest_checkout: true }
  scopes: string[] | null = ['write_all']
  readonly calls: {
    method: string
    path: string
    body?: unknown
    params?: RequestOptions['params']
  }[] = []
  /** What a kinds endpoint lists, by path (with its query string, when it takes one). */
  kinds: Record<string, { type: string; schema?: unknown }[]> = {}
  /** Product ids held by a parent, by `<path>/<id>`. */
  readonly members = new Map<string, string[]>()
  private sequence = 0

  seed(path: string, records: Record<string, unknown>[]): void {
    this.collections.set(
      path,
      records.map((record) => ({ ...record, id: (record.id as string) ?? this.nextId(path) })),
    )
  }

  all(path: string): Record_[] {
    return this.collections.get(path) ?? []
  }

  private nextId(path: string): string {
    this.sequence += 1
    return `${path.replace(/^\//, '').replace(/s$/, '')}_${this.sequence}`
  }

  request = async <T>(method: string, path: string, options: RequestOptions = {}): Promise<T> => {
    this.calls.push({ method, path, body: options.body, params: options.params })
    if (path === '/api_keys/current') return { scopes: this.scopes } as T
    if (path === '/store') {
      if (method === 'PATCH') this.store = { ...this.store, ...(options.body as object) }
      return this.store as T
    }
    const kindsKey = options.params?.type ? `${path}?type=${options.params.type}` : path
    if (method === 'GET' && this.kinds[kindsKey]) return { data: this.kinds[kindsKey] } as T
    const nested = path.match(/^(\/[a-z_]+)\/([^/]+)\/(products|memberships)$/)
    if (nested) return this.nested(method, nested[1], nested[2], nested[3], options.body) as T
    const toggle = path.match(/^\/price_lists\/([^/]+)\/(activate|deactivate)$/)
    if (method === 'PATCH' && toggle) {
      const record = this.find('/price_lists', toggle[1])
      record.status = toggle[2] === 'activate' ? 'active' : 'inactive'
      return record as T
    }
    if (method === 'GET') return this.list(path, options.params ?? {}) as T
    if (method === 'POST' && path === '/products/bulk_add_to_channels')
      return this.publish(options.body, true) as T
    if (method === 'POST' && path === '/products/bulk_remove_from_channels')
      return this.publish(options.body, false) as T
    const reposition = path.match(/^\/categories\/([^/]+)\/reposition$/)
    if (method === 'PATCH' && reposition) {
      const record = this.find('/categories', reposition[1])
      record.parent_id = (options.body as { new_parent_id?: string }).new_parent_id ?? null
      return record as T
    }
    const action = path.match(/^(\/[a-z_]+)\/([^/]+)\/(approve|suspend)$/)
    if (method === 'PATCH' && action) {
      const record = this.find(action[1], action[2])
      record.status = action[3] === 'approve' ? 'approved' : 'suspended'
      return record as T
    }
    if (method === 'POST') {
      const { custom_fields: values, ...written } = options.body as Record<string, unknown>
      const body = this.materializeBody(path, written)
      const record = { ...body, id: this.nextId(path) } as Record_
      this.writeCustomFields(record, values)
      this.collections.set(path, [...this.all(path), record])
      return record as T
    }
    const member = path.match(/^(\/[a-z_]+)\/([^/]+)$/)
    if (!member) throw new Error(`unhandled ${method} ${path}`)
    if (method === 'PATCH') {
      const record = this.find(member[1], member[2])
      const { custom_fields: values, ...written } = options.body as Record<string, unknown>
      Object.assign(
        record,
        this.materializeBody(member[1], { ...written, __live: record, id: record.id }),
      )
      this.writeCustomFields(record, values)
      return record as T
    }
    if (method === 'DELETE') {
      this.collections.set(
        member[1],
        this.all(member[1]).filter((record) => record.id !== member[2]),
      )
      return undefined as T
    }
    throw new Error(`unhandled ${method} ${path}`)
  }

  private find(path: string, id: string): Record_ {
    const record = this.all(path).find((candidate) => candidate.id === id)
    if (!record) {
      const error = new Error('Record not found') as Error & { status: number }
      error.status = 404
      throw error
    }
    return record
  }

  // Product membership and company membership: list, add, remove.
  private nested(method: string, path: string, id: string, kind: string, body: unknown): unknown {
    const parent = this.find(path, id)
    if (kind === 'memberships') {
      const memberships = (parent.memberships as Record_[] | undefined) ?? []
      if (method === 'POST') {
        const { customer_email: email } = body as { customer_email: string }
        const customer = this.all('/customers').find((candidate) => candidate.email === email)
        if (!customer) throw new Error(`no customer ${email}`)
        parent.memberships = [...memberships, { id: this.nextId('/memberships'), email }]
      }
      return { data: parent.memberships ?? [], meta: { pages: 1, next: null } }
    }
    const key = `${path}/${id}`
    const held = this.members.get(key) ?? []
    const ids = ((body as { product_ids?: string[] } | undefined)?.product_ids ?? []).map(String)
    if (method === 'POST') this.members.set(key, [...new Set([...held, ...ids])])
    if (method === 'DELETE')
      this.members.set(
        key,
        held.filter((member) => !ids.includes(member)),
      )
    // A catalog lists its products without their slug.
    const data = (this.members.get(key) ?? []).map((member) => {
      const product = this.find('/products', member)
      return path === '/catalogs' ? { id: product.id, name: product.name } : product
    })
    return { data, meta: { pages: 1, next: null } }
  }

  // A typed set replaces the old one; entries with an id are kept under it,
  // and a kind can be held once, as on a promotion.
  private typedSet(live: unknown, sent: unknown, uniqueKinds: boolean): Record_[] {
    const existing = (live as Record_[] | undefined) ?? []
    const rows = sent as Record<string, unknown>[]
    const kept = rows.flatMap((row) => (row.id ? [row.id] : []))
    const survivors = existing.filter((row) => kept.includes(row.id))
    return rows.map((row) => {
      if (uniqueKinds && !row.id && survivors.some((survivor) => survivor.type === row.type)) {
        const error = new Error('Type has already been taken') as Error & { status: number }
        error.status = 422
        throw error
      }
      return { ...row, id: (row.id as string) ?? this.nextId('/rules') } as Record_
    })
  }

  // Inline values upsert by definition and read back with their namespaced
  // key; a blank value removes the field, and fields not named are kept.
  private writeCustomFields(record: Record_, values: unknown): void {
    if (!Array.isArray(values)) return
    let fields = (record.custom_fields as Record<string, unknown>[] | undefined) ?? []
    for (const { custom_field_definition_id: id, value } of values as Record<string, unknown>[]) {
      const definition = this.find('/custom_field_definitions', id as string)
      fields = fields.filter((field) => field.custom_field_definition_id !== id)
      if (value === null || value === '') continue
      fields.push({
        key: `${definition.namespace}.${definition.key}`,
        field_type: definition.field_type,
        value,
        custom_field_definition_id: id,
      })
    }
    record.custom_fields = fields
  }

  // Products carry their variants and publications inline, like the real
  // serializer when expanded.
  private materializeBody(path: string, sent: Record<string, unknown>): Record<string, unknown> {
    // A PATCH hands in the record being changed, for the sets that keep ids.
    const { __live: live, ...body } = sent
    if (path === '/promotions') body.__live = live
    // The API reads a requirement's type shorthand back as `kind`.
    if (path === '/seller_requirements' && body.type) return { ...body, kind: body.type }
    if (path === '/option_types' && body.option_values) {
      return {
        ...body,
        option_values: (body.option_values as Record<string, unknown>[]).map((value) => ({
          ...value,
          id: (value.id as string) ?? this.nextId('/option_values'),
        })),
      }
    }
    if (path === '/product_types' && body.custom_field_definitions) {
      return {
        ...body,
        custom_field_definitions: (body.custom_field_definitions as Record_[]).map((field) => {
          const definition = this.find('/custom_field_definitions', field.id)
          return { ...field, key: definition.key, namespace: definition.namespace }
        }),
      }
    }
    if (path === '/catalogs' && body.assignments) {
      return {
        ...body,
        assignments: (body.assignments as Record<string, string>[]).map((assignment) => ({
          ...assignment,
          assignable_name: this.find(
            assignment.assignable_type === 'company' ? '/companies' : '/customer_groups',
            assignment.assignable_id,
          ).name,
        })),
      }
    }
    if (path === '/price_lists' && body.rules) {
      const { rules, ...rest } = body
      const live = rest.id ? this.find('/price_lists', rest.id as string).price_rules : []
      return { ...rest, price_rules: this.typedSet(live, rules, false) }
    }
    if (path === '/promotions') {
      const live = body.__live as Record_ | undefined
      const { __live: _live, ...rest } = body
      return {
        ...rest,
        ...(rest.rules ? { rules: this.typedSet(live?.rules, rest.rules, true) } : {}),
        ...(rest.actions ? { actions: this.typedSet(live?.actions, rest.actions, true) } : {}),
      }
    }
    if (path !== '/products') return body
    const { variants, category_ids, ...rest } = body
    const result: Record<string, unknown> = { ...rest }
    if (category_ids) {
      result.categories = (category_ids as string[]).map((id) => this.find('/categories', id))
    }
    if (variants) {
      result.variants = (variants as Record<string, unknown>[]).map((variant) => ({
        id: (variant.id as string) ?? this.nextId('/variants'),
        sku: variant.sku,
        option_values: ((variant.options as { name: string; value: string }[]) ?? []).map(
          (option) => ({
            option_type_name: option.name,
            name: option.value,
          }),
        ),
        prices: ((variant.prices as Record<string, unknown>[]) ?? []).map((price) => ({
          currency: price.currency,
          amount: price.amount === undefined ? null : String(price.amount),
          compare_at_amount:
            price.compare_at_amount === undefined ? null : String(price.compare_at_amount),
          price_list_id: null,
          min_quantity: 1,
        })),
        stock_levels: (variant.stock_levels as unknown[]) ?? [],
      }))
    }
    return result
  }

  private publish(body: unknown, publish: boolean): unknown {
    const { ids, channel_ids } = body as { ids: string[]; channel_ids: string[] }
    for (const id of ids) {
      const product = this.find('/products', id)
      const publications = (
        (product.product_publications as { channel_id: string; unpublished_at: null }[]) ?? []
      ).filter((publication) => !channel_ids.includes(publication.channel_id))
      if (publish)
        publications.push(
          ...channel_ids.map((channel_id) => ({ channel_id, unpublished_at: null })),
        )
      product.product_publications = publications
    }
    return { product_count: ids.length }
  }

  private list(
    path: string,
    params: NonNullable<RequestOptions['params']>,
  ): { data: Record_[]; meta: { pages: number; next: number | null } } {
    let records = this.all(path)
    if (params['q[seller_id_null]']) records = records.filter((record) => !record.seller_id)
    for (const [key, value] of Object.entries(params)) {
      const match = key.match(/^q\[(\w+)_in\]\[\]$/)
      if (!match) continue
      const wanted = (Array.isArray(value) ? value : [value]).map(String)
      records = records.filter((record) => wanted.includes(String(record[match[1]])))
    }
    const limit = Number(params.limit ?? 100)
    const page = Number(params.page ?? 1)
    const data = records.slice((page - 1) * limit, page * limit)
    const pages = Math.max(1, Math.ceil(records.length / limit))
    return { data, meta: { pages, next: page < pages ? page + 1 : null } }
  }
}
