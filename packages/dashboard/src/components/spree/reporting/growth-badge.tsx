import { Badge, cn } from '@spree/dashboard-ui'
import { MinusIcon, TrendingDownIcon, TrendingUpIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { formatMetricNumber, metricNumberForChart } from './metric-numbers'

/**
 * Period-over-period delta indicator: green/red trend arrow + percentage, a
 * neutral dash at 0, and a "New" badge when there is no previous-period
 * baseline (`growth === null`). Growth arrives as a decimal string ("12.5").
 */
export function GrowthBadge({ growth }: { growth: number | string | null | undefined }) {
  const { t, i18n } = useTranslation()

  if (growth === null || growth === undefined || growth === '') {
    return (
      <Badge variant="secondary" title={t('admin.pages.home.growth.vs_previous')}>
        {t('admin.pages.home.growth.new')}
      </Badge>
    )
  }

  const direction = Math.sign(metricNumberForChart(growth))
  const formatted = `${direction > 0 ? '+' : ''}${formatMetricNumber(growth, i18n.language)}%`

  if (direction === 0) {
    return (
      <span
        className="inline-flex items-center gap-0.5 text-xs font-medium text-muted-foreground"
        title={t('admin.pages.home.growth.vs_previous')}
      >
        <MinusIcon className="size-3" />
        {formatted}
      </span>
    )
  }

  return (
    <span
      className={cn(
        'inline-flex items-center gap-0.5 text-xs font-medium',
        // The status trio, not a raw Tailwind ramp: a hand-picked green needs
        // re-tinting for dark mode at every call site, which is what the
        // token family exists to stop.
        direction > 0 ? 'text-success' : 'text-danger',
      )}
      title={t('admin.pages.home.growth.vs_previous')}
    >
      {direction > 0 ? (
        <TrendingUpIcon className="size-3" />
      ) : (
        <TrendingDownIcon className="size-3" />
      )}
      {formatted}
    </span>
  )
}
