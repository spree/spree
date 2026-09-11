import { Badge } from '@spree/dashboard-ui'
import { useDashboardCounters } from '../../hooks/use-dashboard-counters'

/**
 * How many records under a nav entry still need the merchant to do something.
 *
 * The count comes from the counters endpoint, which every badge and the home
 * screen's card share as one request — the sidebar used to spend a list
 * request per badge just to read a total off the pagination meta. Which nav
 * entry a counter badges is the counter's own `nav` field, so an extension
 * registering a counter badges its nav entry without a dashboard release.
 */
export function navCounterBadge(navKey: string) {
  return function NavCounterBadge() {
    const { data } = useDashboardCounters()
    const total = (data?.counters ?? [])
      .filter((counter) => counter.nav === navKey)
      .reduce((sum, counter) => sum + counter.value, 0)

    if (total === 0) return null

    return (
      <Badge variant="outline" className="rounded-lg mr-1">
        {total}
      </Badge>
    )
  }
}
