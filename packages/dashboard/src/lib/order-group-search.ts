/**
 * Search params that open the orders list showing one purchase's orders.
 *
 * A basket spanning several sellers becomes several orders, and the thing an
 * operator wants from any one of them is the rest — so both the orders table
 * and the order page link here rather than each spelling the filter out.
 *
 * The rule is JSON-encoded because that is how the resource table reads
 * filters back off the URL. Columns are deliberately left alone: the `columns`
 * param replaces the whole visible set, so naming any here would hide whatever
 * the operator had chosen.
 *
 * @param orderGroupId prefixed id of the group, as the API reports it
 */
export function orderGroupSearch(orderGroupId: string): { filters: string } {
  const rule = {
    id: `order-group-${orderGroupId}`,
    field: 'order_group',
    operator: 'eq',
    value: orderGroupId,
  }

  return { filters: JSON.stringify([rule]) }
}
