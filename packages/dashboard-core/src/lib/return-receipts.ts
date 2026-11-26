/** A return or exchange line, as far as receiving goes. */
export type ReceivableLine = {
  quantity: number
  received_quantity?: number | null
}

/** The units of a line that have not arrived yet. */
export function unitsToReceive(line: ReceivableLine): number {
  return Math.max(line.quantity - (line.received_quantity ?? 0), 0)
}

/**
 * Whether goods can still be received against a return: once it is approved,
 * and after a partial receipt for as long as any unit is still to come.
 */
export function returnAwaitsGoods(returnRecord: {
  status: string
  return_line_items?: ReceivableLine[] | null
}): boolean {
  if (returnRecord.status === 'approved') return true
  if (returnRecord.status !== 'received') return false

  return (returnRecord.return_line_items ?? []).some((line) => unitsToReceive(line) > 0)
}
