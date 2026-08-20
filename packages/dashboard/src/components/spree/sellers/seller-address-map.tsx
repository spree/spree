import type { Address } from '@spree/admin-sdk'
import { lazy, Suspense } from 'react'
import { useTranslation } from 'react-i18next'

// MapLibre and its styles are a few megabytes, and a map appears on one card
// of one page — loaded on demand so every other screen does not carry it.
const LazyMap = lazy(async () => {
  const map = await import('../../ui/map')

  return { default: map.Map }
})
const LazyMapControls = lazy(async () => {
  const map = await import('../../ui/map')

  return { default: map.MapControls }
})
const LazyMapMarker = lazy(async () => {
  const map = await import('../../ui/map')

  return { default: map.MapMarker }
})
const LazyMarkerContent = lazy(async () => {
  const map = await import('../../ui/map')

  return { default: map.MarkerContent }
})
const LazyMarkerTooltip = lazy(async () => {
  const map = await import('../../ui/map')

  return { default: map.MarkerTooltip }
})

/**
 * Where an address actually is, beside the lines that describe it — a returns
 * address is what shoppers are told to post to, so it is worth seeing on a map
 * rather than trusting as typed.
 *
 * Coordinates are geocoded in the background after the address is saved, so a
 * freshly entered one has none yet; the map is simply absent until then rather
 * than showing the middle of the ocean.
 */
export function SellerAddressMap({ address, label }: { address: Address; label?: string }) {
  const { t } = useTranslation()
  const { latitude, longitude } = address

  if (latitude == null || longitude == null) {
    return (
      <p className="text-muted-foreground text-xs">{t('admin.sellers.address.not_located_yet')}</p>
    )
  }

  return (
    <div className="h-40 overflow-hidden rounded-md border">
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
