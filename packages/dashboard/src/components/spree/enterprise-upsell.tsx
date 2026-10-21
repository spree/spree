import { useStore } from '@spree/dashboard-core'
import { Alert, AlertDescription, AlertTitle, ExternalLink } from '@spree/dashboard-ui'
import { SparklesIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import {
  enterprisePreviewPath,
  enterpriseUrl,
  useEnterprisePreview,
} from '../../lib/enterprise-previews'

// Inside an Alert the links take the alert's own tone rather than the link
// blue, which would fight it.
const ALERT_LINK_CLASS = 'font-medium text-current underline underline-offset-3'

/**
 * Marks a capability that open-source Spree deliberately stops short of, and
 * sends the merchant somewhere they can act on it. Kept as one component so
 * every such prompt in the dashboard reads the same and points at one URL.
 */
export function EnterpriseUpsell({
  title,
  description,
  previewId,
  children,
  className,
}: {
  title: string
  description: string
  /** Preview `id` the link is tagged with. */
  previewId?: string
  /** Extra links shown before the learn-more link. */
  children?: ReactNode
  className?: string
}) {
  const { t } = useTranslation()

  return (
    <Alert variant="info" className={className}>
      <SparklesIcon />
      <AlertTitle>{title}</AlertTitle>
      <AlertDescription className="flex flex-col items-start gap-1.5">
        {description}
        <span className="flex flex-wrap gap-x-4 gap-y-1.5">
          {children}
          <ExternalLink href={enterpriseUrl(previewId)} className={ALERT_LINK_CLASS}>
            {t('admin.enterprise.learn_more')}
          </ExternalLink>
        </span>
      </AlertDescription>
    </Alert>
  )
}

/**
 * The in-context note for an Enterprise preview, linking to its preview page.
 * Renders nothing once Spree Enterprise has replaced the preview, or when
 * previews are switched off.
 */
export function EnterprisePreviewNote({
  previewKey,
  className,
}: {
  /** Preview key, e.g. `orders.quotes`. */
  previewKey: string
  className?: string
}) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const preview = useEnterprisePreview(previewKey)
  if (!preview) return null

  const base = `admin.enterprise.previews.${preview.id}.note`

  return (
    <EnterpriseUpsell
      title={t(`${base}.title`)}
      description={t(`${base}.description`)}
      previewId={preview.id}
      className={className}
    >
      {/* Paths come from a runtime registry, so they can't be checked against
          the generated route tree. */}
      <Link to={enterprisePreviewPath(preview, storeId) as never} className={ALERT_LINK_CLASS}>
        {t('admin.enterprise.see_how_it_works')}
      </Link>
    </EnterpriseUpsell>
  )
}
