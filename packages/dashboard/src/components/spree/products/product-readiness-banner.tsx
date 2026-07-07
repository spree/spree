import { useTranslation } from 'react-i18next'
import { useProductReadiness } from '@/hooks/use-product'

/**
 * Surfaces `Spree::Products::ReadinessCheck` (status, per-channel
 * publication, per-market price, purchasable stock, per-market
 * translations) on the product edit page. None of these checks block a
 * save — a merchant can save an incomplete product on purpose (draft price,
 * translation still in progress) — so this is a warning, not a form error.
 * Renders nothing while loading, on fetch failure, or once every check
 * passes — this is a hint, not a load-bearing status the page depends on.
 *
 * Visual style mirrors the existing "orphaned variants" warning banner in
 * `variants-section.tsx` — the one warning-banner convention already
 * established in this codebase.
 */
export function ProductReadinessBanner({ productId }: { productId: string }) {
  const { t } = useTranslation()
  const { data } = useProductReadiness(productId)

  if (!data || data.ready) return null

  const failedChecks = data.checks.filter((check) => !check.ready && check.message)

  return (
    <div
      role="status"
      className="rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm dark:border-amber-700 dark:bg-amber-950/40"
    >
      <p className="font-medium text-amber-900 dark:text-amber-100">
        {t('admin.products.readiness.title')}
      </p>
      <p className="mt-0.5 text-amber-800 dark:text-amber-200">
        {t('admin.products.readiness.description')}
      </p>
      {failedChecks.length > 0 && (
        <ul className="mt-1 list-disc pl-5 text-amber-900 dark:text-amber-200">
          {failedChecks.map((check) => (
            <li key={check.key}>{check.message}</li>
          ))}
        </ul>
      )}
    </div>
  )
}
