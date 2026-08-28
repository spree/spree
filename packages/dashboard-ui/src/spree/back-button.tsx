import { useParams, useRouter } from '@tanstack/react-router'
import { ArrowLeftIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'

interface BackButtonProps {
  /**
   * Fallback path segment under the current tenant when there is no history to
   * go back to. Example: "products" → navigates to `/$storeId/products` in the
   * operator's dashboard, `/$sellerId/products` in a seller's panel.
   */
  fallback: string
  className?: string
}

/**
 * Back button that goes to the previous page in history (preserving that page's
 * state — filters, column selection, etc.), falling back to the tenant's list
 * page when there's nothing to go back to (e.g. deep-link, new tab).
 */
export function BackButton({ fallback, className }: BackButtonProps) {
  const { t } = useTranslation()
  const router = useRouter()
  // Whichever tenant this panel routes under. Reading `storeId` alone sent a
  // seller to `/undefined/...`, since their routes are keyed `$sellerId` —
  // this component is shared, so it cannot assume the operator's param name.
  const params = useParams({ strict: false }) as { storeId?: string; sellerId?: string }
  const tenantId = params.storeId ?? params.sellerId

  const handleClick = (e: React.MouseEvent) => {
    e.preventDefault()
    // If there's history within the app, go back to preserve previous state
    if (window.history.length > 1 && document.referrer.includes(window.location.host)) {
      router.history.back()
    } else if (tenantId) {
      // Fallback to the list page
      router.navigate({ to: `/${tenantId}/${fallback}` as string })
    }
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      className={
        className ??
        'inline-flex items-center justify-center rounded-lg p-1.5 text-muted-foreground bg-transparent hover:bg-accent hover:text-foreground transition-colors'
      }
      aria-label={t('admin.actions.back')}
    >
      <ArrowLeftIcon className="size-5" />
    </button>
  )
}
