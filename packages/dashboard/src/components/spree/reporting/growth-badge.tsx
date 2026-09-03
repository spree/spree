import { Badge, cn } from '@spree/dashboard-ui'
import { MinusIcon, TrendingDownIcon, TrendingUpIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'

/**
 * Period-over-period delta indicator: green/red trend arrow + percentage, a
 * neutral dash at 0, and a "New" badge when there is no previous-period
 * baseline (`growth === null`).
 */
export function GrowthBadge({ growth }: { growth: number | null | undefined }) {
  const { t } = useTranslation()

  if (growth === null || growth === undefined) {
    return (
      <Badge variant="secondary" title={t('admin.pages.home.growth.vs_previous')}>
        {t('admin.pages.home.growth.new')}
      </Badge>
    )
  }

  const formatted = `${growth > 0 ? '+' : ''}${growth.toLocaleString()}%`

  if (growth === 0) {
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
        growth > 0 ? 'text-green-700 dark:text-green-400' : 'text-destructive',
      )}
      title={t('admin.pages.home.growth.vs_previous')}
    >
      {growth > 0 ? <TrendingUpIcon className="size-3" /> : <TrendingDownIcon className="size-3" />}
      {formatted}
    </span>
  )
}
