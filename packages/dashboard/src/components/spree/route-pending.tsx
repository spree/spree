import { Skeleton } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/**
 * Router-wide fallback while a route's code chunk or loader resolves.
 *
 * Deliberately generic: it stands in for pages whose shape isn't known here,
 * so it sketches the one thing they all share — a title, then a body — rather
 * than pretending to know a page's real layout. Pages that can do better ship
 * their own pending UI.
 */
export function RoutePending() {
  const { t } = useTranslation()
  return (
    <div className="flex flex-col gap-4 p-4 lg:p-6" aria-busy="true">
      {/* `aria-busy` marks the region pending but announces nothing on its own —
          screen readers need actual text to read out. */}
      <span role="status" className="sr-only">
        {t('admin.common.loading')}
      </span>
      <div className="flex flex-col gap-2">
        <Skeleton className="h-7 w-48" />
        <Skeleton className="h-4 w-72" />
      </div>
      <Skeleton className="h-64 w-full rounded-xl" />
    </div>
  )
}

/**
 * Placeholder for a detail page whose record is still loading. Mirrors
 * `ResourceLayout`: a header block, then the main/sidebar split — so the page
 * doesn't reflow when the real content replaces it.
 */
export function ResourceDetailSkeleton({ sidebar = true }: { sidebar?: boolean }) {
  const { t } = useTranslation()
  return (
    <div className="flex flex-col gap-6" aria-busy="true">
      <span role="status" className="sr-only">
        {t('admin.common.loading')}
      </span>
      <div className="flex flex-col gap-2">
        <Skeleton className="h-8 w-64" />
        <Skeleton className="h-4 w-40" />
      </div>
      {sidebar ? (
        <div className="grid grid-cols-12 gap-6">
          <div className="col-span-12 flex flex-col gap-6 lg:col-span-8">
            <Skeleton className="h-48 w-full rounded-xl" />
            <Skeleton className="h-64 w-full rounded-xl" />
          </div>
          <div className="col-span-12 flex flex-col gap-6 lg:col-span-4">
            <Skeleton className="h-40 w-full rounded-xl" />
            <Skeleton className="h-32 w-full rounded-xl" />
          </div>
        </div>
      ) : (
        <div className="flex flex-col gap-6">
          <Skeleton className="h-48 w-full rounded-xl" />
          <Skeleton className="h-64 w-full rounded-xl" />
        </div>
      )}
    </div>
  )
}
