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
  // Serialized so the debounce and the query key compare by content.
  const current = JSON.stringify(placed ? buildOrderChangeActions(items) : [])
  const settled = useDebouncedValue(current, PREVIEW_DELAY_MS)
  const staged = current !== '[]'

  const query = useQuery({
    queryKey: useResourceKey('orders', order?.id ?? '', 'order_change_preview', settled),
    queryFn: () =>
      adminClient.orders.orderChanges.preview(order?.id ?? '', { actions: JSON.parse(settled) }),
    enabled: placed && settled !== '[]',
    // Keeps the last figures on screen while the next ones load, rather than
    // flashing back to the saved totals between keystrokes.
    placeholderData: keepPreviousData,
    // The same staged edits give the same answer until the order itself is
    // saved, which refreshes the page anyway.
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
