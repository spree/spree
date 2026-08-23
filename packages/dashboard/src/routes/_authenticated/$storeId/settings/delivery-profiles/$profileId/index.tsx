import { zodResolver } from '@hookform/resolvers/zod'
import type {
  DeliveryMethod,
  DeliveryOriginGroup,
  DeliveryProfile,
  DeliveryZone,
  DeliveryZoneMember,
} from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  PageHeader,
  Subject,
  usePermissions,
  useStore,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
  ErrorState,
  Field,
  FieldError,
  FieldLabel,
  Input,
  ResourceLayout,
  RowActions,
  Tooltip,
  TooltipContent,
  TooltipTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import {
  GlobeIcon,
  MapIcon,
  PlusIcon,
  SplitIcon,
  StoreIcon,
  TruckIcon,
  WarehouseIcon,
  ZapIcon,
} from 'lucide-react'
import { useMemo, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { DeliveryMethodSheet } from '../../../../../../components/spree/shipping/delivery-method-sheet'
import { DeliveryOriginGroupDialog } from '../../../../../../components/spree/shipping/delivery-origin-group-dialog'
import { DeliveryZoneSheet } from '../../../../../../components/spree/shipping/delivery-zone-sheet'
import { StockLocationScopeField } from '../../../../../../components/spree/shipping/stock-location-scope-field'
import {
  useAllDeliveryMethods,
  useDeleteDeliveryMethod,
  useDeliveryRateProviders,
} from '../../../../../../hooks/use-delivery-methods'
import { useDeleteDeliveryOriginGroup } from '../../../../../../hooks/use-delivery-origin-groups'
import {
  useDeleteDeliveryProfile,
  useDeliveryProfile,
  useUpdateDeliveryProfile,
} from '../../../../../../hooks/use-delivery-profiles'
import {
  useDeleteDeliveryZone,
  useProfileDeliveryZones,
} from '../../../../../../hooks/use-delivery-zones'
import {
  useStockLocations,
  useUpdateStockLocationById,
} from '../../../../../../hooks/use-stock-locations'
import {
  flatAmount,
  formatAmount,
  summarizeRules,
} from '../../../../../../lib/delivery-method-summary'
import { spreeJsonLinkResolver } from '../../../../../../lib/json-link-resolver'
import {
  type DeliveryProfileGeneralValues,
  type DeliveryProfileLocationsValues,
  deliveryProfileGeneralSchema,
  deliveryProfileLocationsSchema,
  deliveryProfileLocationsToParams,
} from '../../../../../../schemas/delivery-profile'

/**
 * The method sheet is driven from the URL so a deep link opens it over a live
 * profile page: `method` is either a method's ID or `new`, and `zone`, `group`
 * and `provider` preselect what a new method is being created for.
 */
const profileDetailSearchSchema = z.object({
  method: z.string().optional(),
  zone: z.string().optional(),
  group: z.string().optional(),
  provider: z.enum(['pickup', 'digital']).optional(),
})

type ProfileDetailSearch = z.infer<typeof profileDetailSearchSchema>

export const Route = createFileRoute(
  '/_authenticated/$storeId/settings/delivery-profiles/$profileId/',
)({
  validateSearch: profileDetailSearchSchema,
  component: DeliveryProfileDetailPage,
})

/**
 * Opens the method sheet for an existing method, or for a new one.
 *
 * Every move replaces the history entry rather than pushing one. The sheet
 * lives in the URL so a deep link reopens it, but opening and closing one is
 * not a place a merchant navigated to — pushing would leave the page's back
 * arrow walking through sheets they already dismissed instead of returning to
 * the profile list.
 */
function useMethodSheetNavigation() {
  const navigate = useNavigate()

  const openMethod = (methodId: string) =>
    navigate({
      replace: true,
      search: (prev: Record<string, unknown>) => {
        const { zone: _z, group: _g, provider: _p, ...rest } = prev
        return { ...rest, method: methodId } as never
      },
    })

  const openNewMethod = (options: { zone?: string; group?: string; provider?: string } = {}) =>
    navigate({
      replace: true,
      search: (prev: Record<string, unknown>) =>
        ({
          ...prev,
          method: 'new',
          ...(options.zone ? { zone: options.zone } : { zone: undefined }),
          ...(options.group ? { group: options.group } : { group: undefined }),
          ...(options.provider ? { provider: options.provider } : { provider: undefined }),
        }) as never,
    })

  const closeMethodSheet = () =>
    navigate({
      replace: true,
      search: (prev: Record<string, unknown>) => {
        const { method: _m, zone: _z, group: _g, provider: _p, ...rest } = prev
        return rest as never
      },
    })

  return { openMethod, openNewMethod, closeMethodSheet }
}

function DeliveryProfileDetailPage() {
  const { t } = useTranslation()
  const { profileId } = Route.useParams()
  const { data: profile, isLoading, error, refetch } = useDeliveryProfile(profileId)

  if (isLoading) {
    return <p className="text-muted-foreground">{t('admin.common.loading')}</p>
  }
  if (error || !profile) {
    return (
      <ErrorState
        title={t('admin.delivery_profiles.detail.load_failed_title')}
        description={error instanceof Error ? error.message : undefined}
        onRetry={() => refetch()}
      />
    )
  }
  return <DeliveryProfileDetailBody profile={profile} />
}

function DeliveryProfileDetailBody({ profile }: { profile: DeliveryProfile }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryProfile()

  async function handleDelete() {
    const ok = await confirm({
      title: t('admin.delivery_profiles.delete_confirm.title'),
      message: t('admin.delivery_profiles.delete_confirm.message', { name: profile.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(profile.id)
    navigate({ to: '/$storeId/settings/delivery-profiles', params: { storeId } })
  }

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={profile.name}
          backTo="settings/delivery-profiles"
          resource={{ id: profile.id }}
          jsonPreview={{
            title: `Delivery profile ${profile.name}`,
            fetch: () => adminClient.deliveryProfiles.get(profile.id),
            endpoint: `/api/v3/admin/delivery_profiles/${profile.id}`,
            resolveLink: spreeJsonLinkResolver(storeId),
          }}
          onDelete={profile.default ? undefined : handleDelete}
          deleteLabel={t('admin.delivery_profiles.detail.delete_label')}
        />
      }
      main={<ZonesAndMethodsSection profile={profile} />}
      sidebar={
        <>
          <GeneralCard profile={profile} />
          <OriginsCard profile={profile} />
        </>
      }
    />
  )
}

// ---------------------------------------------------------------------------
// General — name, kind, and promotion to store default
// ---------------------------------------------------------------------------

function GeneralCard({ profile }: { profile: DeliveryProfile }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const updateMutation = useUpdateDeliveryProfile(profile.id)

  const form = useForm<DeliveryProfileGeneralValues>({
    resolver: zodResolver(deliveryProfileGeneralSchema),
    defaultValues: { name: profile.name },
    values: { name: profile.name },
    resetOptions: { keepDirtyValues: true },
  })

  async function onSubmit(values: DeliveryProfileGeneralValues) {
    try {
      await updateMutation.mutateAsync({ name: values.name })
      form.reset(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  async function handleMakeDefault() {
    const ok = await confirm({
      title: t('admin.delivery_profiles.default_confirm.title'),
      message: t('admin.delivery_profiles.default_confirm.message', { name: profile.name }),
      confirmLabel: t('admin.delivery_profiles.make_default'),
    })
    if (!ok) return
    await updateMutation.mutateAsync({ default: true }).catch(() => undefined)
  }

  const { errors } = form.formState

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.delivery_profiles.detail.general_title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {errors.root?.message && (
          <p className="text-sm text-destructive" role="alert">
            {errors.root.message}
          </p>
        )}
        <Field>
          <FieldLabel htmlFor="profile-name">{t('admin.fields.name.label')}</FieldLabel>
          <Input
            id="profile-name"
            aria-invalid={!!errors.name || undefined}
            {...form.register('name')}
          />
          <FieldError errors={[errors.name]} />
        </Field>

        <Field>
          <FieldLabel>{t('admin.fields.delivery_profile.kind.label')}</FieldLabel>
          <div>
            <Badge variant="outline">
              {t(`admin.delivery_profiles.kinds.${profile.kind}`, {
                defaultValue: profile.kind,
              })}
            </Badge>
          </div>
          <span className="text-muted-foreground text-xs">
            {t('admin.delivery_profiles.kind_immutable_hint')}
          </span>
        </Field>

        <Field>
          <FieldLabel>{t('admin.delivery_profiles.default_badge')}</FieldLabel>
          {profile.default ? (
            <span className="text-muted-foreground text-xs">
              {t('admin.delivery_profiles.is_default_hint')}
            </span>
          ) : (
            <Can I="update" a={Subject.DeliveryProfile}>
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="self-start"
                onClick={handleMakeDefault}
                disabled={updateMutation.isPending}
              >
                {t('admin.delivery_profiles.make_default')}
              </Button>
            </Can>
          )}
        </Field>

        <Can I="update" a={Subject.DeliveryProfile}>
          <Button
            type="button"
            size="sm"
            className="self-start"
            onClick={form.handleSubmit(onSubmit)}
            disabled={form.formState.isSubmitting || !form.formState.isDirty}
          >
            {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </Can>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Origins — which stock locations this profile ships from
// ---------------------------------------------------------------------------

function OriginsCard({ profile }: { profile: DeliveryProfile }) {
  const { t } = useTranslation()
  const updateMutation = useUpdateDeliveryProfile(profile.id)
  const { data: stockLocations } = useStockLocations()

  const initial: DeliveryProfileLocationsValues = {
    scope: profile.stock_location_ids.length === 0 ? 'all' : 'selected',
    stock_location_ids: profile.stock_location_ids,
  }

  const form = useForm<DeliveryProfileLocationsValues>({
    resolver: zodResolver(deliveryProfileLocationsSchema),
    defaultValues: initial,
    values: initial,
    resetOptions: { keepDirtyValues: true },
  })

  const scope = form.watch('scope')

  async function onSubmit(values: DeliveryProfileLocationsValues) {
    try {
      await updateMutation.mutateAsync(deliveryProfileLocationsToParams(values))
      form.reset(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.delivery_profiles.detail.origins_title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <Controller
          name="stock_location_ids"
          control={form.control}
          render={({ field }) => (
            <StockLocationScopeField
              idPrefix="origins"
              scope={scope}
              onScopeChange={(next) => {
                form.setValue('scope', next, { shouldDirty: true })
                if (next === 'all') field.onChange([])
              }}
              locations={stockLocations?.data ?? []}
              selectedIds={field.value}
              onSelectedIdsChange={field.onChange}
              allLabel={t('admin.delivery_profiles.all_locations')}
              selectedLabel={t('admin.delivery_profiles.selected_locations')}
              emptyLabel={t('admin.delivery_profiles.detail.no_stock_locations')}
            />
          )}
        />

        <Can I="update" a={Subject.DeliveryProfile}>
          <Button
            type="button"
            size="sm"
            className="self-start"
            onClick={form.handleSubmit(onSubmit)}
            disabled={form.formState.isSubmitting || !form.formState.isDirty}
          >
            {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </Can>
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Methods, split by how they reach the customer. Zones are a destination
// concept, so only address-shipping methods are filed under them; pickup and
// digital methods get their own cards, with no zone language at all.
// ---------------------------------------------------------------------------

function ZonesAndMethodsSection({ profile }: { profile: DeliveryProfile }) {
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
        <DigitalMethodsCard methods={digitalMethods} />
        <MethodSheetOutlet profile={profile} zones={zones ?? []} />
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
          <OriginGroupSection
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

      <PickupCard methods={pickupMethods} />

      {digitalMethods.length > 0 && <DigitalMethodsCard methods={digitalMethods} />}

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

      <MethodSheetOutlet profile={profile} zones={zones ?? []} />
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
}: {
  profile: DeliveryProfile
  zones: DeliveryZone[]
}) {
  const search = Route.useSearch() as ProfileDetailSearch
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
        <ZoneCard
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
 * One origin group of a split profile: the warehouses it ships from, and the
 * zones and methods priced from them. Same cards as the flat rendering, under
 * a header that names the origin.
 */
function OriginGroupSection({
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
        <ZoneCard
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

// ---------------------------------------------------------------------------
// Pickup — the methods customers collect in person, and which counters they
// can collect from.
// ---------------------------------------------------------------------------

function PickupCard({ methods }: { methods: DeliveryMethod[] }) {
  const { t } = useTranslation()
  const { openNewMethod } = useMethodSheetNavigation()

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <StoreIcon className="size-4 text-muted-foreground" />
          {t('admin.delivery_profiles.detail.pickup_title')}
        </CardTitle>
        <span className="text-muted-foreground text-xs">
          {t('admin.delivery_profiles.detail.pickup_hint')}
        </span>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        {methods.length > 0 ? (
          <MethodList methods={methods} icon={StoreIcon} />
        ) : (
          <div className="flex flex-col items-start gap-2">
            <p className="text-muted-foreground text-sm">
              {t('admin.delivery_profiles.detail.pickup_empty')}
            </p>
            <Can I="create" a={Subject.DeliveryMethod}>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => openNewMethod({ provider: 'pickup' })}
              >
                <PlusIcon className="size-4" />
                {t('admin.delivery_profiles.detail.offer_pickup')}
              </Button>
            </Can>
          </div>
        )}

        <PickupLocationsBlock />
      </CardContent>
    </Card>
  )
}

/**
 * Every stock location of the store, each a counter customers can collect
 * from. Toggling writes straight through — the surrounding page is a set of
 * saved forms, so the helper line says these changes are immediate.
 */
function PickupLocationsBlock() {
  const { t } = useTranslation()
  const { data: stockLocations, isLoading } = useStockLocations()
  const updateMutation = useUpdateStockLocationById()

  const locations = stockLocations?.data ?? []

  return (
    <div className="flex flex-col gap-2 border-t pt-4">
      <span className="font-medium text-sm">
        {t('admin.delivery_profiles.detail.collect_from')}
      </span>
      <span className="text-muted-foreground text-xs">
        {t('admin.delivery_profiles.detail.collect_from_hint')}
      </span>

      {isLoading ? (
        <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
      ) : locations.length === 0 ? (
        <p className="text-muted-foreground text-sm">
          {t('admin.delivery_profiles.detail.no_stock_locations')}
        </p>
      ) : (
        <div className="flex flex-col gap-2">
          {locations.map((location) => (
            <label
              key={location.id}
              htmlFor={`pickup-location-${location.id}`}
              className="flex items-center gap-2 text-sm"
            >
              <Checkbox
                id={`pickup-location-${location.id}`}
                checked={location.pickup_enabled}
                disabled={updateMutation.isPending}
                onCheckedChange={(next) =>
                  updateMutation
                    .mutateAsync({
                      id: location.id,
                      params: { pickup_enabled: !!next },
                    })
                    .catch(() => undefined)
                }
              />
              {location.name}
            </label>
          ))}
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// Digital — delivered without a destination of any kind
// ---------------------------------------------------------------------------

function DigitalMethodsCard({ methods }: { methods: DeliveryMethod[] }) {
  const { t } = useTranslation()
  const { openNewMethod } = useMethodSheetNavigation()

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ZapIcon className="size-4 text-muted-foreground" />
          {t('admin.delivery_profiles.detail.digital_title')}
        </CardTitle>
        <span className="text-muted-foreground text-xs">
          {t('admin.delivery_profiles.detail.digital_hint')}
        </span>
      </CardHeader>
      <CardContent>
        {methods.length > 0 ? (
          <MethodList methods={methods} icon={ZapIcon} />
        ) : (
          <div className="flex flex-col items-start gap-2">
            <p className="text-muted-foreground text-sm">
              {t('admin.delivery_profiles.detail.digital_empty')}
            </p>
            <Can I="create" a={Subject.DeliveryMethod}>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => openNewMethod({ provider: 'digital' })}
              >
                <PlusIcon className="size-4" />
                {t('admin.delivery_profiles.detail.add_digital_method')}
              </Button>
            </Can>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function ZoneCard({
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
        <MethodList methods={methods} />
      </CardContent>
    </Card>
  )
}

/**
 * Methods offered wherever the profile reaches. Always rendered, even empty:
 * a profile with no zones would otherwise have nowhere to add a method from,
 * and a carrier method that quotes worldwide never wants a zone at all.
 */
function UnrestrictedMethodsCard({
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
          <MethodList methods={methods} />
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

function MethodList({
  methods,
  icon: Icon = TruckIcon,
}: {
  methods: DeliveryMethod[]
  icon?: typeof TruckIcon
}) {
  const { t, i18n } = useTranslation()
  const { store, defaultCurrency } = useStore()
  const { openMethod } = useMethodSheetNavigation()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryMethod()
  const { permissions } = usePermissions()
  const { data: rateProviders } = useDeliveryRateProviders()
  const defaultRateProvider = rateProviders?.default ?? ''

  async function handleDelete(method: DeliveryMethod) {
    const ok = await confirm({
      title: t('admin.delivery_methods.delete_confirm.title'),
      message: t('admin.delivery_methods.delete_confirm.message', { name: method.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(method.id).catch(() => undefined)
  }

  if (methods.length === 0) {
    return (
      <p className="text-muted-foreground text-sm">
        {t('admin.delivery_profiles.detail.no_methods')}
      </p>
    )
  }

  return (
    <div className="flex flex-col divide-y">
      {methods.map((method) => {
        const rateProvider = (rateProviders?.data ?? []).find(
          (provider) => provider.type === method.rate_provider,
        )
        // A carrier quotes each shipment live, so this column answers what the
        // price IS rather than naming the provider — which the method is
        // usually named after anyway. Everything else is priced up front: an
        // amount, or free when there is none.
        //
        // A method carrying a rate provider absent from the registry (an
        // uninstalled gem, a disconnected integration) is still not
        // calculator-priced, and calling it free would be a lie about money.
        const carrierPriced = rateProvider
          ? rateProvider.uses_calculator === false
          : !!method.rate_provider && method.rate_provider !== defaultRateProvider
        const amount = flatAmount(method.calculator_preferences)
        const price = carrierPriced
          ? t('admin.delivery_methods.carrier_rates')
          : amount === null || amount === 0
            ? t('admin.delivery_methods.free')
            : formatAmount(amount, defaultCurrency, i18n.language)

        const ruleSummary = summarizeRules(method.rules, {
          t,
          currency: defaultCurrency,
          weightUnit: store?.preferred_weight_unit ?? 'lb',
          locale: i18n.language,
        })

        return (
          <div key={method.id} className="flex items-center justify-between gap-2 py-2">
            <button
              type="button"
              className="flex flex-1 items-center gap-2 text-left"
              onClick={() => openMethod(method.id)}
            >
              <Icon className="size-4 shrink-0 text-muted-foreground" />
              <span className="flex flex-col">
                <span className="text-sm">{method.name}</span>
                {ruleSummary && (
                  <span className="text-muted-foreground text-xs">{ruleSummary}</span>
                )}
              </span>
            </button>
            {!method.storefront_visible && (
              <Badge variant="outline">{t('admin.delivery_profiles.detail.hidden_badge')}</Badge>
            )}
            {carrierPriced ? (
              <Tooltip>
                <TooltipTrigger
                  render={
                    <span className="shrink-0 cursor-default text-sm underline decoration-dotted underline-offset-2">
                      {price}
                    </span>
                  }
                />
                <TooltipContent className="max-w-xs">
                  {t('admin.delivery_methods.carrier_rates_hint', {
                    name: rateProvider?.name ?? method.name,
                  })}
                </TooltipContent>
              </Tooltip>
            ) : (
              <span className="shrink-0 text-sm tabular-nums">{price}</span>
            )}
            <RowActions
              actions={[
                {
                  key: 'edit',
                  onSelect: () => openMethod(method.id),
                },
                {
                  key: 'delete',
                  destructive: true,
                  visible: permissions.can('destroy', Subject.DeliveryMethod),
                  disabled: deleteMutation.isPending,
                  onSelect: () => handleDelete(method),
                },
              ]}
            />
          </div>
        )
      })}
    </div>
  )
}
