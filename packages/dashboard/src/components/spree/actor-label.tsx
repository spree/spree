import type { Actor } from '@spree/admin-sdk'
import { KeyRoundIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'

/**
 * Who performed an action — a member of staff, or the API key an integration
 * called with. A key is marked with an icon so "cancelled by WMS connector"
 * reads as a machine rather than as a colleague with an odd name.
 */
export function ActorLabel({ actor }: { actor?: Actor | null }) {
  const { t } = useTranslation()

  if (!actor) return null

  const label = actor.label ?? t('admin.actors.unnamed')

  if (actor.type !== 'api_key') return <>{label}</>

  return (
    <span className="inline-flex items-center gap-1.5">
      <KeyRoundIcon className="size-3.5 text-muted-foreground" aria-hidden />
      {label}
      <span className="sr-only">{t('admin.actors.api_key')}</span>
    </span>
  )
}
