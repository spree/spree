import { listAll, listByKeys } from '../client.js'
import type { RunContext } from '../context.js'
import type { LiveRecord } from '../types.js'
import type { Payload } from './section.js'

/**
 * Categories, collections, catalogs and price lists hold products through
 * the same nested endpoints: list, add any number, remove any number. A file
 * names the members by slug, and the list is the whole set.
 */

async function memberSlugs(ctx: RunContext, path: string, live: LiveRecord): Promise<string[]> {
  const members = await listAll(ctx.client, `${path}/${live.id}/products`, { fields: 'id,slug' })
  if (members.every((product) => product.slug))
    return members.map((product) => String(product.slug))
  // Some parents list their members without a slug; the products have it.
  const products = await listByKeys(
    ctx.client,
    '/products',
    'id',
    members.map((product) => product.id),
    { fields: 'id,slug' },
  )
  return products.map((product) => String(product.slug))
}

/** The members an entry declares, in a stable order; every slug must name a product. */
export async function desiredMembers(
  slugs: string[] | undefined,
  ctx: RunContext,
  path: string,
): Promise<Payload> {
  if (!slugs) return {}
  await Promise.all(slugs.map((slug) => ctx.ref('products', slug, path)))
  return { products: [...slugs].sort() }
}

/** The live members, when the entry declares any. */
export async function liveMembers(
  ctx: RunContext,
  path: string,
  live: LiveRecord,
  desired: Payload,
): Promise<Payload> {
  if (!desired.products) return {}
  return { products: (await memberSlugs(ctx, path, live)).sort() }
}

/** Adds and removes products until the record holds exactly the declared ones. */
export async function syncMembers(
  ctx: RunContext,
  path: string,
  live: LiveRecord,
  slugs: string[] | undefined,
): Promise<void> {
  if (!slugs) return
  const current = await memberSlugs(ctx, path, live)
  const idsOf = (list: string[]) =>
    Promise.all(
      list.map(async (slug) => {
        const product = await ctx.find('products', slug)
        if (!product) throw new Error(`product "${slug}" does not exist`)
        return product.id
      }),
    )
  const add = await idsOf(slugs.filter((slug) => !current.includes(slug)))
  const remove = await idsOf(current.filter((slug) => !slugs.includes(slug)))
  const members = `${path}/${live.id}/products`
  if (add.length) await ctx.client.request('POST', members, { body: { product_ids: add } })
  if (remove.length) await ctx.client.request('DELETE', members, { body: { product_ids: remove } })
}

/** A live record's members as the file writes them. */
export async function membersToFile(
  ctx: RunContext,
  path: string,
  live: LiveRecord,
): Promise<{ products?: string[] }> {
  const slugs = await memberSlugs(ctx, path, live)
  return slugs.length ? { products: slugs } : {}
}
