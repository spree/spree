/**
 * A hand-picked part of a value list. Its own values keep their narrow type,
 * while `includes` takes any string, since the API may answer with a status
 * the subset leaves out or one an extension added.
 */
export interface Subset<Value extends string> extends ReadonlyArray<Value> {
  includes(value: string): boolean
}

/**
 * A hand-picked part of a generated value list — the statuses an action
 * accepts, say. Each value is checked against the list's built-in values, so a
 * typo or a value the server dropped fails to compile.
 *
 * @example
 * const OWED = subsetOf(SELLER_PAYOUT_STATUSES, ['pending', 'processing', 'unresolved'])
 * OWED.includes(payout.status)
 */
export function subsetOf<const Value extends string, const Picked extends Value>(
  _list: readonly Value[],
  subset: readonly Picked[],
): Subset<Picked> {
  return subset
}
