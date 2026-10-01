import type { Order, OrderGroup } from './types'

/**
 * Whether a checkout completion answered with the group a multi-seller cart
 * divided into, rather than with one order.
 *
 * Keyed on `orders`, which only the group carries — the payload has no type
 * discriminator of its own.
 */
export function isOrderGroup(result: Order | OrderGroup): result is OrderGroup {
  return Array.isArray((result as OrderGroup).orders)
}
