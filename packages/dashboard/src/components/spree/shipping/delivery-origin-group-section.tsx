import type {
  DeliveryMethod,
  DeliveryOriginGroup,
  DeliveryProfile,
  DeliveryZone,
} from '@spree/admin-sdk'
import { Can, Subject, usePermissions, useStockLocations } from '@spree/dashboard-core'
import { Button, RowActions, useConfirm } from '@spree/dashboard-ui'
import { PlusIcon, WarehouseIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useDeleteDeliveryOriginGroup } from '../../../hooks/use-delivery-origin-groups'
import { DeliveryOriginGroupDialog } from './delivery-origin-group-dialog'
import { DeliveryZoneCard, UnrestrictedMethodsCard } from './delivery-zone-card'

/**
 * One origin group of a split profile: the warehouses it ships from, and the
 * zones and methods priced from them. Same cards as the flat rendering, under
 * a header that names the origin.
 */
export function DeliveryOriginGroupSection({
  profile,
  group,
  zones,
  methods,
  onAddZone,
  onEditZone,
}: {
  profile: DeliveryProfile
  group: DeliveryProfile['origin_groups'][number]
  zones: DeliveryZone[]
  methods: DeliveryMethod[]
  onAddZone: () => void
  onEditZone: (zoneId: string) => void
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { permissions } = usePermissions()
  const { data: stockLocations } = useStockLocations()
  const deleteMutation = useDeleteDeliveryOriginGroup(profile.id)
  const [editing, setEditing] = useState(false)

  const unrestricted = methods.filter((method) => !method.delivery_zone_id)
  const locationNames = (stockLocations?.data ?? [])
    .filter((location) => group.stock_location_ids.includes(location.id))
    .map((location) => location.name)

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.delivery_origin_groups.delete_confirm.title'),
      message: t('admin.delivery_origin_groups.delete_confirm.message', {
        name: group.name ?? t('admin.delivery_profiles.all_locations'),
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    // Deleting cascades to the group's zones and methods — the confirm says
    // so. Only the profile's last group is refused (422, surfaced as a toast).
    await deleteMutation.mutateAsync(group.id).catch(() => undefined)
  }

  return (
    <section className="flex flex-col gap-4 rounded-lg border p-4">
      <div className="flex items-start justify-between gap-2">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-2">
            <WarehouseIcon className="size-4 text-muted-foreground" />
            <span className="font-medium text-sm">
              {group.name || t('admin.delivery_profiles.all_locations')}
            </span>
          </div>
          <span className="text-muted-foreground text-xs">
            {locationNames.length > 0
              ? t('admin.delivery_origin_groups.ships_from', {
                  locations: locationNames.join(', '),
                })
              : t('admin.delivery_origin_groups.ships_from_all')}
          </span>
        </div>
        <div className="flex items-center gap-2">
          <Can I="create" a={Subject.DeliveryZone}>
            <Button type="button" variant="outline" size="sm" onClick={onAddZone}>
              <PlusIcon className="size-4" />
              {t('admin.delivery_zones.add_cta')}
            </Button>
          </Can>
          <RowActions
            actions={[
              {
                key: 'edit',
                visible: permissions.can('update', Subject.DeliveryProfile),
                onSelect: () => setEditing(true),
              },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('update', Subject.DeliveryProfile),
                disabled: deleteMutation.isPending,
                onSelect: handleDelete,
              },
            ]}
          />
        </div>
      </div>

      {zones.map((zone) => (
        <DeliveryZoneCard
          key={zone.id}
          zone={zone}
          methods={methods.filter((method) => method.delivery_zone_id === zone.id)}
          onEdit={() => onEditZone(zone.id)}
          originGroupId={group.id}
        />
      ))}

      <UnrestrictedMethodsCard methods={unrestricted} originGroupId={group.id} />

      {editing && (
        <DeliveryOriginGroupDialog
          deliveryProfileId={profile.id}
          group={group as DeliveryOriginGroup}
          open
          onOpenChange={(open) => !open && setEditing(false)}
        />
      )}
    </section>
  )
}
