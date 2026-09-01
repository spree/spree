import type { DeliveryMethod, DeliveryProfile, DeliveryZone } from '@spree/admin-sdk'
import { Can, Subject } from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { PlusIcon, SplitIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useAllDeliveryMethods } from '../../../hooks/use-delivery-methods'
import { useProfileDeliveryZones } from '../../../hooks/use-delivery-zones'
import { DeliveryDigitalMethodsCard } from './delivery-digital-methods-card'
import { DeliveryMethodSheet } from './delivery-method-sheet'
import { DeliveryOriginGroupDialog } from './delivery-origin-group-dialog'
import { DeliveryOriginGroupSection } from './delivery-origin-group-section'
import { DeliveryPickupCard } from './delivery-pickup-card'
import { DeliveryZoneCard, UnrestrictedMethodsCard } from './delivery-zone-card'
import { DeliveryZoneSheet } from './delivery-zone-sheet'
import { useMethodSheetNavigation } from './use-method-sheet-navigation'

/** What the URL carries about the method sheet on the profile detail page. */
export type MethodSheetSearch = {
  method?: string
  zone?: string
  group?: string
  provider?: 'pickup' | 'digital'
}

/**
 * Methods, split by how they reach the customer. Zones are a destination
 * concept, so only address-shipping methods are filed under them; pickup and
 * digital methods get their own cards, with no zone language at all.
 */
export function DeliveryZonesAndMethodsSection({
  profile,
  search,
}: {
  profile: DeliveryProfile
  search: MethodSheetSearch
}) {
  const { t } = useTranslation()
  const { data: zones, isLoading: zonesLoading } = useProfileDeliveryZones(profile.id)
  const { data: allMethods, isLoading: methodsLoading } = useAllDeliveryMethods()
  const [zoneSheet, setZoneSheet] = useState<{ zoneId?: string; groupId?: string } | null>(null)
  const [splitting, setSplitting] = useState(false)

  const methods = (allMethods ?? []).filter((method) => method.delivery_profile_id === profile.id)
  const pickupMethods = methods.filter((method) => method.pickup || method.pickup_point)
  const digitalMethods = methods.filter((method) => method.digital)
  const shippingMethods = methods.filter(
    (method) => !method.digital && !method.pickup && !method.pickup_point,
  )

  const groups = [...(profile.origin_groups ?? [])].sort(
    (a, b) => (a.position ?? 0) - (b.position ?? 0),
  )
  // Until a profile is split, the origin-group layer is invisible: one group
  // means one flat list of zones, exactly as before groups existed.
  const split = groups.length > 1

  if (zonesLoading || methodsLoading) {
    return <p className="text-muted-foreground">{t('admin.common.loading')}</p>
  }

  // A digital profile has no destination and no counter, so zones would be
  // meaningless there — it gets the digital card alone. The method sheet still
  // rides along, since digital methods are edited through it too.
  if (profile.digital) {
    return (
      <>
        <DeliveryDigitalMethodsCard methods={digitalMethods} />
        <MethodSheetOutlet profile={profile} zones={zones ?? []} search={search} />
      </>
    )
  }

  return (
    <>
      <div className="flex items-center justify-between">
        <h2 className="font-medium text-base">{t('admin.delivery_profiles.detail.zones_title')}</h2>
        <div className="flex items-center gap-2">
          <Can I="update" a={Subject.DeliveryProfile}>
            <Button type="button" variant="ghost" size="sm" onClick={() => setSplitting(true)}>
              <SplitIcon className="size-4" />
              {t('admin.delivery_origin_groups.split_cta')}
            </Button>
          </Can>
          {!split && (
            <Can I="create" a={Subject.DeliveryZone}>
              <Button type="button" variant="outline" size="sm" onClick={() => setZoneSheet({})}>
                <PlusIcon className="size-4" />
                {t('admin.delivery_zones.add_cta')}
              </Button>
            </Can>
          )}
        </div>
      </div>

      {split ? (
        groups.map((group) => (
          <DeliveryOriginGroupSection
            key={group.id}
            profile={profile}
            group={group}
            zones={(zones ?? []).filter((zone) => zone.delivery_origin_group_id === group.id)}
            methods={shippingMethods.filter(
              (method) => method.delivery_origin_group_id === group.id,
            )}
            onAddZone={() => setZoneSheet({ groupId: group.id })}
            onEditZone={(zoneId) => setZoneSheet({ zoneId })}
          />
        ))
      ) : (
        <FlatZoneList
          zones={zones ?? []}
          methods={shippingMethods}
          onEditZone={(zoneId) => setZoneSheet({ zoneId })}
        />
      )}

      <DeliveryPickupCard methods={pickupMethods} />

      {digitalMethods.length > 0 && <DeliveryDigitalMethodsCard methods={digitalMethods} />}

      {zoneSheet && (
        <DeliveryZoneSheet
          deliveryProfileId={profile.id}
          deliveryOriginGroupId={zoneSheet.groupId}
          zoneId={zoneSheet.zoneId}
          siblingZones={zones ?? []}
          open
          onOpenChange={(open) => !open && setZoneSheet(null)}
        />
      )}

      {splitting && (
        <DeliveryOriginGroupDialog
          deliveryProfileId={profile.id}
          open
          onOpenChange={(open) => !open && setSplitting(false)}
        />
      )}

      <MethodSheetOutlet profile={profile} zones={zones ?? []} search={search} />
    </>
  )
}

/**
 * The zones of one profile with no origin-group framing at all — what a
 * merchant who never split their origins sees, and what they return to after
 * deleting the second group.
 */
function FlatZoneList({
  zones,
  methods,
  onEditZone,
}: {
  zones: DeliveryZone[]
  methods: DeliveryMethod[]
  onEditZone: (zoneId: string) => void
}) {
  const unrestricted = methods.filter((method) => !method.delivery_zone_id)

  return (
    <>
      {zones.map((zone) => (
        <DeliveryZoneCard
          key={zone.id}
          zone={zone}
          methods={methods.filter((method) => method.delivery_zone_id === zone.id)}
          onEdit={() => onEditZone(zone.id)}
        />
      ))}

      <UnrestrictedMethodsCard methods={unrestricted} />
    </>
  )
}

/**
 * Renders the method sheet whenever the URL asks for one. Kept apart from the
 * page body so the profile stays mounted underneath: opening a method is a
 * search-param change, not a navigation away.
 */
function MethodSheetOutlet({
  profile,
  zones,
  search,
}: {
  profile: DeliveryProfile
  zones: DeliveryZone[]
  search: MethodSheetSearch
}) {
  const { closeMethodSheet } = useMethodSheetNavigation()

  if (!search.method) return null

  const creating = search.method === 'new'

  return (
    <DeliveryMethodSheet
      // Remounting on the method being edited drops the previous record's
      // form state, which a shared instance would otherwise carry over.
      key={search.method}
      profile={profile}
      zones={zones}
      methodId={creating ? undefined : search.method}
      zoneId={creating ? search.zone : undefined}
      originGroupId={creating ? search.group : undefined}
      provider={creating ? search.provider : undefined}
      open
      onOpenChange={(open) => !open && closeMethodSheet()}
    />
  )
}
