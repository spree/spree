import { lazy, Suspense } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Structural shape `<AddressMap>` needs. Declared here rather than imported
 * so the design system stays decoupled from any SDK's `Address` type — the
 * same reason `<AddressBlock>` carries its own.
 */
export interface AddressMapValue {
  latitude?: number | null
  longitude?: number | null
}

// MapLibre and its styles are a few megabytes for a map that appears on one
// card of a page, so it is loaded on demand and every other screen is spared.
const LazyMap = lazy(async () => ({ default: (await import('../ui/map')).Map }))
const LazyMapControls = lazy(async () => ({ default: (await import('../ui/map')).MapControls }))
const LazyMapMarker = lazy(async () => ({ default: (await import('../ui/map')).MapMarker }))
const LazyMarkerContent = lazy(async () => ({ default: (await import('../ui/map')).MarkerContent }))
const LazyMarkerTooltip = lazy(async () => ({ default: (await import('../ui/map')).MarkerTooltip }))

/**
 * Where an address actually is, beside the lines that describe it — a returns
 * address is what shoppers are told to post to, so it is worth seeing on a map
 * rather than trusting as typed.
 *
 * Coordinates are geocoded in the background after an address is saved, so a
 * freshly entered one has none yet; the map is simply absent until then rather
 * than showing the middle of the ocean.
 */
export function AddressMap({
  address,
  label,
  className,
}: {
  address: AddressMapValue
  /** Names whose address the pin marks — a seller, a customer, a branch. */
  label?: string
  className?: string
}) {
  const { t } = useTranslation()
  const { latitude, longitude } = address

  if (latitude == null || longitude == null) {
    return <p className="text-muted-foreground text-xs">{t('admin.address.not_located_yet')}</p>
  }

  return (
    <div className={className ?? 'h-40 overflow-hidden rounded-md border'}>
      <Suspense fallback={<div className="size-full animate-pulse bg-muted" />}>
        <LazyMap center={[longitude, latitude]} zoom={13}>
          <LazyMapControls />
          <LazyMapMarker longitude={longitude} latitude={latitude}>
            {/* The default pin; the tooltip names whose address it is. */}
            <LazyMarkerContent />
            {label && <LazyMarkerTooltip>{label}</LazyMarkerTooltip>}
          </LazyMapMarker>
        </LazyMap>
      </Suspense>
    </div>
  )
}
