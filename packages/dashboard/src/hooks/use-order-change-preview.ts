import type { Order } from '@spree/admin-sdk'
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useDebouncedValue } from '@spree/dashboard-ui'
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { buildOrderChangeActions, type OrderEditItemValues } from '../schemas/order'

const PREVIEW_DELAY_MS = 300

/**
 * The server's own totals for a placed order with the staged edits applied —
 * computed and thrown away, nothing is saved. Debounced, so typing a quantity
 * asks once it settles rather than per keystroke. Drafts are not previewed
 * here: their edits are written directly and projected client-side.
 */
export function useOrderChangePreview(order: Order | undefined, items: OrderEditItemValues[]) {
  const placed = Boolean(order?.completed_at)
  const actions = JSON.stringify(placed ? buildOrderChangeActions(items) : [])
  // Serialized so the debounce and the query key compare by content. The
  // order and its revision ride along: moving to another order must not
  // send one order's line ids against the next, and an order changed
  // elsewhere answers the same edits differently.
  const current = JSON.stringify([order?.id, order?.updated_at, actions])
  const settled = useDebouncedValue(current, PREVIEW_DELAY_MS)
  const [settledOrderId, , settledActions] = JSON.parse(settled) as [
    string | null,
    string | null,
    string,
  ]
  const staged = actions !== '[]'

  const query = useQuery({
    // Not under the order's key: a save invalidates that, and refetching
    // would re-preview the just-saved edits on top of themselves.
    queryKey: useResourceKey('order_change_previews', settled),
    queryFn: () =>
      adminClient.orders.orderChanges.preview(settledOrderId ?? '', {
        actions: JSON.parse(settledActions),
      }),
    enabled: placed && settledOrderId === order?.id && settledActions !== '[]',
    // Keeps the last figures on screen while the next ones load, rather than
    // flashing back to the saved totals between keystrokes.
    placeholderData: keepPreviousData,
    // The same staged edits on the same revision give the same answer.
    staleTime: Number.POSITIVE_INFINITY,
    refetchOnWindowFocus: false,
    retry: false,
  })

  return {
    preview: staged ? query.data : undefined,
    isPending: staged && (query.isFetching || settled !== current),
    error: staged ? query.error : null,
  }
}
