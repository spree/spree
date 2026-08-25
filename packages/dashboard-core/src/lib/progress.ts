/** A count of finished items out of a total — an onboarding checklist, say. */
export interface ProgressCounts {
  done: number
  total: number
}

/**
 * How far through a checklist something is, as a percentage for a progress bar.
 *
 * An empty checklist counts as complete rather than as nothing done: a
 * marketplace that asks nothing of its sellers has no outstanding work, and
 * `done / total` would be NaN.
 */
export function progressPercentage({ done, total }: ProgressCounts): number {
  if (total <= 0) return 100

  return Math.round((done / total) * 100)
}
