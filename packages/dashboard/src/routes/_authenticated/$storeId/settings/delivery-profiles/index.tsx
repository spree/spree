import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryProfile } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
  useStockLocations,
} from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RadioGroup,
  RadioGroupItem,
  RowActions,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateDeliveryProfile,
  useDeleteDeliveryProfile,
  useDeliveryProfileKinds,
} from '../../../../../hooks/use-delivery-profiles'
import {
  DELIVERY_PROFILE_CREATE_DEFAULTS,
  type DeliveryProfileCreateValues,
  deliveryProfileCreateSchema,
} from '../../../../../schemas/delivery-profile'
import '../../../../../tables/delivery-profiles'

const shippingSearchSchema = resourceSearchSchema.extend({
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/delivery-profiles/')({
  validateSearch: shippingSearchSchema,
  component: ShippingPage,
})

function ShippingPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch() as z.infer<typeof shippingSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryProfile()
  const { permissions } = usePermissions()

  const isCreating = !!search.new

  const closeDialog = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openProfile = (profileId: string) =>
    navigate({
      to: '/$storeId/settings/delivery-profiles/$profileId',
      params: { storeId, profileId },
    })

  useRowClickBridge('data-delivery-profile-id', openProfile)

  async function handleDelete(profile: DeliveryProfile) {
    const ok = await confirm({
      title: t('admin.delivery_profiles.delete_confirm.title'),
      message: t('admin.delivery_profiles.delete_confirm.message', { name: profile.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(profile.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<DeliveryProfile>
        tableKey="delivery-profiles"
        queryKey="delivery-profiles"
        queryFn={(params) => adminClient.deliveryProfiles.list(params)}
        searchParams={search}
        rowActions={(profile) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openProfile(profile.id) },
              {
                key: 'delete',
                destructive: true,
                // The store default profile is what every unassigned product
                // falls back to, so the server refuses to delete it — don't
                // offer an action that can only fail.
                visible: !profile.default && permissions.can('destroy', Subject.DeliveryProfile),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(profile),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.DeliveryProfile}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.delivery_profiles.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateProfileDialog onClose={closeDialog} />}
    </>
  )
}

function CreateProfileDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const createMutation = useCreateDeliveryProfile()
  const { data: kinds } = useDeliveryProfileKinds()
  const { data: stockLocations } = useStockLocations()

  const form = useForm<DeliveryProfileCreateValues>({
    resolver: zodResolver(deliveryProfileCreateSchema),
    defaultValues: DELIVERY_PROFILE_CREATE_DEFAULTS,
  })

  const originsScope = form.watch('origins_scope')

  const kindOptions = (kinds?.data ?? []).map((entry) => ({
    value: entry.kind,
    label: t(`admin.delivery_profiles.kinds.${entry.kind}`, { defaultValue: entry.kind }),
  }))

  async function onSubmit(values: DeliveryProfileCreateValues) {
    try {
      const profile = await createMutation.mutateAsync({
        name: values.name,
        kind: values.kind,
        // Empty means every location, including ones added later.
        stock_location_ids: values.origins_scope === 'all' ? [] : values.stock_location_ids,
      })
      onClose()
      // A new profile is empty: send the merchant straight to it, where the
      // zones and methods that make it useful get added.
      navigate({
        to: '/$storeId/settings/delivery-profiles/$profileId',
        params: { storeId, profileId: profile.id },
      })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.delivery_profiles.add_dialog_title')}</DialogTitle>
          <DialogDescription>{t('admin.delivery_profiles.create_description')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogBody>
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-sm text-destructive" role="alert">
                  {errors.root.message}
                </p>
              )}
              <Field>
                <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
                <Input
                  id="name"
                  autoFocus
                  aria-invalid={!!errors.name || undefined}
                  {...form.register('name')}
                />
                <FieldError errors={[errors.name]} />
              </Field>

              <Field>
                <FieldLabel>{t('admin.fields.delivery_profile.kind.label')}</FieldLabel>
                <Controller
                  name="kind"
                  control={form.control}
                  render={({ field }) => (
                    <Select items={kindOptions} value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {kindOptions.map((option) => (
                          <SelectItem key={option.value} value={option.value}>
                            {option.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
                <span className="text-muted-foreground text-xs">
                  {t('admin.fields.delivery_profile.kind.help')}
                </span>
              </Field>

              <Field>
                <FieldLabel>{t('admin.fields.delivery_profile.origins.label')}</FieldLabel>
                {/* "All locations" is an empty set, not every box ticked —
                    naming locations freezes the profile to today's list and
                    silently excludes any warehouse added later. */}
                <Controller
                  name="origins_scope"
                  control={form.control}
                  render={({ field }) => (
                    <RadioGroup value={field.value} onValueChange={field.onChange}>
                      <label
                        htmlFor="create-profile-origins-all"
                        className="flex items-center gap-2 text-sm"
                      >
                        <RadioGroupItem id="create-profile-origins-all" value="all" />
                        {t('admin.delivery_profiles.all_locations')}
                      </label>
                      <label
                        htmlFor="create-profile-origins-selected"
                        className="flex items-center gap-2 text-sm"
                      >
                        <RadioGroupItem id="create-profile-origins-selected" value="selected" />
                        {t('admin.delivery_profiles.selected_locations')}
                      </label>
                    </RadioGroup>
                  )}
                />

                {originsScope === 'selected' && (
                  <Controller
                    name="stock_location_ids"
                    control={form.control}
                    render={({ field }) => (
                      <div className="flex flex-col gap-2">
                        {(stockLocations?.data ?? []).map((location) => (
                          <label
                            key={location.id}
                            htmlFor={`create-profile-location-${location.id}`}
                            className="flex items-center gap-2 text-sm"
                          >
                            <Checkbox
                              id={`create-profile-location-${location.id}`}
                              checked={field.value.includes(location.id)}
                              onCheckedChange={(next) =>
                                field.onChange(
                                  next
                                    ? [...field.value, location.id]
                                    : field.value.filter((id: string) => id !== location.id),
                                )
                              }
                            />
                            {location.name}
                          </label>
                        ))}
                      </div>
                    )}
                  />
                )}
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={onClose}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.delivery_profiles.create_label')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
