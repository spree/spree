import type { ConfigClient, LiveRecord, RequestOptions } from './types.js'

const PAGE_LIMIT = 100
/** Keys per `q[<key>_in][]` request, well under any URL length limit. */
const KEY_CHUNK = 50

interface Paginated<T> {
  data: T[]
  meta?: { pages?: number; next?: number | null }
}

/** Every page of a list endpoint. */
export async function listAll<T extends LiveRecord = LiveRecord>(
  client: ConfigClient,
  path: string,
  params: RequestOptions['params'] = {},
): Promise<T[]> {
  const records: T[] = []
  let page = 1
  for (;;) {
    const response = await client.request<Paginated<T>>('GET', path, {
      params: { ...params, page, limit: PAGE_LIMIT },
    })
    records.push(...response.data)
    if (!response.meta?.next) break
    page = response.meta.next
  }
  return records
}

/**
 * Records whose natural key is one of `keys`, fetched in chunks through a
 * Ransack `_in` predicate so a large catalog is never listed whole.
 */
export async function listByKeys<T extends LiveRecord = LiveRecord>(
  client: ConfigClient,
  path: string,
  keyAttribute: string,
  keys: string[],
  params: RequestOptions['params'] = {},
): Promise<T[]> {
  const records: T[] = []
  for (let index = 0; index < keys.length; index += KEY_CHUNK) {
    const chunk = keys.slice(index, index + KEY_CHUNK)
    records.push(
      ...(await listAll<T>(client, path, { ...params, [`q[${keyAttribute}_in][]`]: chunk })),
    )
  }
  return records
}
