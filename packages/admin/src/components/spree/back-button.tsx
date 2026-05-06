import { useParams, useRouter } from '@tanstack/react-router'
import { ArrowLeftIcon } from 'lucide-react'

interface BackButtonProps {
  /**
   * Fallback path segment under the current store when there is no history to go back to.
   * Example: "products" → navigates to `/$storeId/products`
   */
  fallback: string
  className?: string
}

/**
 * Back button that goes to the previous page in history (preserving that page's
 * state — filters, column selection, etc.), falling back to `/$storeId/{fallback}`
 * when there's nothing to go back to (e.g. deep-link, new tab).
 */
export function BackButton({ fallback, className }: BackButtonProps) {
  const router = useRouter()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }

  const handleClick = (e: React.MouseEvent) => {
    e.preventDefault()
    // If there's history within the app, go back to preserve previous state
    if (window.history.length > 1 && document.referrer.includes(window.location.host)) {
      router.history.back()
    } else {
      // Fallback to the list page
      router.navigate({ to: `/${storeId}/${fallback}` as string })
    }
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      className={
        className ??
        'inline-flex items-center justify-center rounded-lg p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground transition-colors'
      }
      aria-label="Back"
    >
      <ArrowLeftIcon className="size-5" />
    </button>
  )
}
