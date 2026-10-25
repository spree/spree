import { Badge, Tooltip, TooltipContent, TooltipTrigger } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/**
 * The info alert's softer blue rather than the info badge: an Enterprise mark
 * reads as a label beside its entry or title, not a status. Applied over the
 * outline variant.
 */
export const ENTERPRISE_BADGE_CLASS =
  'border-blue-500/20 bg-blue-500/10 text-blue-800 dark:text-blue-300 [a]:hover:bg-blue-500/20 [a]:hover:text-blue-800 dark:[a]:hover:text-blue-300'

/** Marks a sidebar entry that previews a Spree Enterprise feature. */
export function EnterpriseNavBadge() {
  const { t } = useTranslation()

  return (
    <Tooltip>
      {/* A span, not a button: the badge sits inside the entry's link, which
          already takes focus. */}
      <TooltipTrigger asChild>
        <Badge
          variant="outline"
          className={`${ENTERPRISE_BADGE_CLASS} h-4 px-1.5 text-[10px] tracking-wide uppercase`}
        >
          {t('admin.enterprise.badge')}
        </Badge>
      </TooltipTrigger>
      <TooltipContent side="right">{t('admin.enterprise.available_in')}</TooltipContent>
    </Tooltip>
  )
}
