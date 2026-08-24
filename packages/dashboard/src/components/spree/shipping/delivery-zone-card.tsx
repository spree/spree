import type { DeliveryMethod, DeliveryZone, DeliveryZoneMember } from '@spree/admin-sdk'
import { Can, Subject, usePermissions } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  RowActions,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import { GlobeIcon, MapIcon, PlusIcon } from 'lucide-react'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useDeleteDeliveryZone } from '../../../hooks/use-delivery-zones'
import { DeliveryMethodList } from './delivery-method-list'
import { useMethodSheetNavigation } from './use-method-sheet-navigation'

export function DeliveryZoneCard({
  zone,
  methods,
  onEdit,
  originGroupId,
}: {
  zone: DeliveryZone
  methods: DeliveryMethod[]
  onEdit: () => void
  /** Set only on a split profile, so a new method lands in the right group. */
  originGroupId?: string
}) {
  const { t } = useTranslation()
  const { openNewMethod } = useMethodSheetNavigation()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryZone()
  const { permissions } = usePermissions()

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.delivery_zones.delete_confirm.title'),
      message: t('admin.delivery_zones.delete_confirm.message', { name: zone.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(zone.id).catch(() => undefined)
  }

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-2">
        <div className="flex flex-col gap-1">
          <CardTitle className="flex items-center gap-2">
            <MapIcon className="size-4 text-muted-foreground" />
            {zone.name}
          </CardTitle>
          <ZoneMembersSummary zone={zone} />
        </div>
        <div className="flex items-center gap-2">
          <Can I="create" a={Subject.DeliveryMethod}>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => openNewMethod({ zone: zone.id, group: originGroupId })}
            >
              <PlusIcon className="size-4" />
              {t('admin.delivery_profiles.detail.add_method')}
            </Button>
          </Can>
          <RowActions
            actions={[
              { key: 'edit', onSelect: onEdit },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.DeliveryZone),
                disabled: deleteMutation.isPending,
                onSelect: handleDelete,
              },
            ]}
          />
        </div>
      </CardHeader>
      <CardContent>
        <DeliveryMethodList methods={methods} />
      </CardContent>
    </Card>
  )
}

/**
 * Methods offered wherever the profile reaches. Always rendered, even empty:
 * a profile with no zones would otherwise have nowhere to add a method from,
 * and a carrier method that quotes worldwide never wants a zone at all.
 */
export function UnrestrictedMethodsCard({
  methods,
  originGroupId,
}: {
  methods: DeliveryMethod[]
  originGroupId?: string
}) {
  const { t } = useTranslation()
  const { openNewMethod } = useMethodSheetNavigation()

  return (
    <Card>
      <CardHeader className="flex flex-row items-start justify-between gap-2">
        <div className="flex flex-col gap-1">
          <CardTitle className="flex items-center gap-2">
            <GlobeIcon className="size-4 text-muted-foreground" />
            {t('admin.delivery_profiles.detail.no_zone_title')}
          </CardTitle>
          <span className="text-muted-foreground text-xs">
            {t('admin.delivery_profiles.detail.no_zone_hint')}
          </span>
        </div>
        <Can I="create" a={Subject.DeliveryMethod}>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => openNewMethod({ group: originGroupId })}
          >
            <PlusIcon className="size-4" />
            {t('admin.delivery_profiles.detail.add_method')}
          </Button>
        </Can>
      </CardHeader>
      {methods.length > 0 && (
        <CardContent>
          <DeliveryMethodList methods={methods} />
        </CardContent>
      )}
    </Card>
  )
}

/**
 * Names the places a zone covers: the first few members, then the rest behind
 * a tooltip. Countries come first because they are how merchants think about
 * a zone; states and postal-code rules follow when a zone is finer-grained.
 */
function ZoneMembersSummary({ zone }: { zone: DeliveryZone }) {
  const { t } = useTranslation()

  const names = useMemo(() => {
    const members = zone.members ?? []
    const label = (member: DeliveryZoneMember): string | null => {
      if (member.member_type === 'country') return member.country_name ?? member.country_code
      if (member.member_type === 'state') return member.state_name ?? member.state_code
      if (member.postal_code_prefix) return `${member.postal_code_prefix}*`
      if (member.postal_code_from && member.postal_code_to) {
        return `${member.postal_code_from}–${member.postal_code_to}`
      }
      return member.postal_code_from ?? member.postal_code_to
    }

    const order = { country: 0, state: 1 } as Record<string, number>
    return [...members]
      .sort((a, b) => (order[a.member_type] ?? 2) - (order[b.member_type] ?? 2))
      .map(label)
      .filter((name): name is string => !!name)
  }, [zone.members])

  if (names.length === 0) return null

  const shown = names.slice(0, 3)
  const remaining = names.slice(3)

  return (
    <span className="text-muted-foreground text-xs">
      {shown.join(t('admin.delivery_zones.member_separator'))}
      {remaining.length > 0 && (
        <>
          {t('admin.delivery_zones.member_separator')}
          <Tooltip>
            <TooltipTrigger asChild>
              <button type="button" className="underline decoration-dotted underline-offset-2">
                {t('admin.delivery_zones.members_more', { count: remaining.length })}
              </button>
            </TooltipTrigger>
            <TooltipContent className="max-w-xs">
              {remaining.join(t('admin.delivery_zones.member_separator'))}
            </TooltipContent>
          </Tooltip>
        </>
      )}
    </span>
  )
}
