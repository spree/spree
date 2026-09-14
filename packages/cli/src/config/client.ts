import type { ConfigClient, LiveRecord, RequestOptions } from './types.js'

const PAGE_LIMIT = 100
/** Keys per `q[<key>_in][]` request, well under any URL length limit. */
const KEY_CHUNK = 50
/** Requests in flight at once while listing. */
const CONCURRENCY = 4

interface Paginated<T> {
  data: T[]
  meta?: { pages?: number }
}

async function inBatches<T, R>(items: T[], run: (item: T) => Promise<R>): Promise<R[]> {
  const results: R[] = []
  for (let index = 0; index < items.length; index += CONCURRENCY) {
    results.push(...(await Promise.all(items.slice(index, index + CONCURRENCY).map(run))))
  }
  return results
}

/** Every page of a list endpoint: the first tells how many follow, the rest come in parallel. */
export async function listAll<T extends LiveRecord = LiveRecord>(
  client: ConfigClient,
  path: string,
  params: RequestOptions['params'] = {},
): Promise<T[]> {
  const page = (number: number) =>
    client.request<Paginated<T>>('GET', path, {
      params: { ...params, page: number, limit: PAGE_LIMIT },
    })
  const first = await page(1)
  const remaining = Array.from(
    { length: Math.max(0, (first.meta?.pages ?? 1) - 1) },
    (_, index) => index + 2,
  )
  const rest = await inBatches(remaining, page)
  return [first, ...rest].flatMap((response) => response.data)
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
  const chunks = Array.from({ length: Math.ceil(keys.length / KEY_CHUNK) }, (_, index) =>
    keys.slice(index * KEY_CHUNK, (index + 1) * KEY_CHUNK),
  )
  const results = await inBatches(chunks, (chunk) =>
    listAll<T>(client, path, { ...params, [`q[${keyAttribute}_in][]`]: chunk }),
  )
  return results.flat()
}
