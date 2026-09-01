import { Alert, AlertDescription, AlertTitle } from '@spree/dashboard-ui'
import { ExternalLinkIcon, SparklesIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'

export const SPREE_ENTERPRISE_URL = 'https://spreecommerce.org/enterprise/'

/**
 * Marks a capability that open-source Spree deliberately stops short of, and
 * sends the merchant somewhere they can act on it. Kept as one component so
 * every such prompt in the dashboard reads the same and points at one URL.
 */
export function EnterpriseUpsell({
  title,
  description,
  className,
}: {
  title: string
  description: string
  className?: string
}) {
  const { t } = useTranslation()

  return (
    <Alert variant="info" className={className}>
      <SparklesIcon />
      <AlertTitle>{title}</AlertTitle>
      <AlertDescription className="flex flex-col items-start gap-1.5">
        {description}
        <a
          href={SPREE_ENTERPRISE_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-1 font-medium text-current underline underline-offset-3"
        >
          {t('admin.enterprise.learn_more')}
          <ExternalLinkIcon className="size-3.5" />
        </a>
      </AlertDescription>
    </Alert>
  )
}
