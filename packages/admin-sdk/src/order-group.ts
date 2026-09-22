import type Order from './types/generated/Order'
import type OrderGroup from './types/generated/OrderGroup'

/**
 * Whether a completion answered with the group a multi-seller order divided
 * into, rather than with one order.
 *
 * Keyed on `seller_count`, which only the group carries — the payload has no
 * type discriminator of its own.
 */
export function isOrderGroup(result: Order | OrderGroup): result is OrderGroup {
  return 'seller_count' in result
}
