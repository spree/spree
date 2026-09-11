import { Badge } from '@spree/dashboard-ui'
import { useDashboardCounters } from '../../hooks/use-dashboard-counters'

/**
 * How many records under a nav entry still need the merchant to do something.
 *
 * A parent entry passes its own key plus its children's, so the count stays
 * visible while the submenu is collapsed — the sidebar only mounts children of
 * the section you are in, and a number nobody can see until they have already
 * navigated there is not worth having. Expanding the section then breaks the
 * same total down across the children.
 *
 * Which entry a counter badges is the counter's own `nav` field, so an
 * extension registering a counter badges its nav entry without a dashboard
 * release. The count itself comes from the shared counters request.
 */
export function navCounterBadge(...navKeys: string[]) {
  return function NavCounterBadge() {
    const { data } = useDashboardCounters()
    const total = (data?.counters ?? [])
      .filter((counter) => counter.nav && navKeys.includes(counter.nav))
      .reduce((sum, counter) => sum + counter.value, 0)

    if (total === 0) return null

    return (
      <Badge variant="outline" className="rounded-lg mr-1">
        {total}
      </Badge>
    )
  }
}
