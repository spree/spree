import type { ConfigClient, RequestOptions } from '../src/config/types'

type Record_ = Record<string, unknown> & { id: string }

/**
 * An in-memory stand-in for the Admin API: paginated lists with `_in`
 * filters, the store singleton, creates, updates, deletes and the handful of
 * action endpoints the engine calls. Enough to plan and apply against.
 */
export class FakeApi implements ConfigClient {
  readonly collections = new Map<string, Record_[]>()
  store: Record_ = { id: 'store_1', name: 'Shop', preferred_guest_checkout: true }
  scopes: string[] | null = ['write_all']
  readonly calls: {
    method: string
    path: string
    body?: unknown
    params?: RequestOptions['params']
  }[] = []
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
    if (method === 'GET') return this.list(path, options.params ?? {}) as T
    if (method === 'POST' && path === '/products/bulk_add_to_channels')
      return this.publish(options.body, true) as T
    if (method === 'POST' && path === '/products/bulk_remove_from_channels')
      return this.publish(options.body, false) as T
    const action = path.match(/^(\/[a-z_]+)\/([^/]+)\/(approve|suspend)$/)
    if (method === 'POST' && action) {
      const record = this.find(action[1], action[2])
      record.status = action[3] === 'approve' ? 'approved' : 'suspended'
      return record as T
    }
    if (method === 'POST') {
      const body = this.materializeBody(path, options.body as Record<string, unknown>)
      const record = { ...body, id: this.nextId(path) } as Record_
      this.collections.set(path, [...this.all(path), record])
      return record as T
    }
    const member = path.match(/^(\/[a-z_]+)\/([^/]+)$/)
    if (!member) throw new Error(`unhandled ${method} ${path}`)
    if (method === 'PATCH') {
      const record = this.find(member[1], member[2])
      Object.assign(
        record,
        this.materializeBody(member[1], options.body as Record<string, unknown>),
      )
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

  // Products carry their variants and publications inline, like the real
  // serializer when expanded.
  private materializeBody(path: string, body: Record<string, unknown>): Record<string, unknown> {
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
  ): { data: Record_[]; meta: { next: number | null } } {
    let records = this.all(path)
    for (const [key, value] of Object.entries(params)) {
      const match = key.match(/^q\[(\w+)_in\]\[\]$/)
      if (!match) continue
      const wanted = (Array.isArray(value) ? value : [value]).map(String)
      records = records.filter((record) => wanted.includes(String(record[match[1]])))
    }
    const limit = Number(params.limit ?? 100)
    const page = Number(params.page ?? 1)
    const data = records.slice((page - 1) * limit, page * limit)
    return { data, meta: { next: page * limit < records.length ? page + 1 : null } }
  }
}
