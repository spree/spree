import { ExternalLinkIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'

/**
 * Link to a provider's setup guide, opened in a new tab. Renders nothing for
 * a missing URL or anything but an absolute http(s) one, since the URL comes
 * from provider gem code rather than the dashboard.
 */
export function SetupGuideLink({ url }: { url: string | null | undefined }) {
  const { t } = useTranslation()
  if (!url || !/^https?:\/\//.test(url)) return null

  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      className="link inline-flex w-fit items-center gap-1 text-sm"
    >
      {t('admin.integrations.setup_guide')}
      <ExternalLinkIcon className="size-3.5" />
    </a>
  )
}
