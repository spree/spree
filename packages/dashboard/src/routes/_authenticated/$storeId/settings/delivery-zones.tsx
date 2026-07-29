import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryZone } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Textarea,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, Trash2Icon } from 'lucide-react'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateDeliveryZone,
  useDeleteDeliveryZone,
  useDeliveryZone,
  useUpdateDeliveryZone,
} from '../../../../hooks/use-delivery-zones'
import {
  DELIVERY_ZONE_DEFAULTS,
  type DeliveryZoneFormValues,
  deliveryZoneFormSchema,
  deliveryZoneValuesToParams,
  MEMBER_TYPES,
} from '../../../../schemas/delivery-zone'
import '../../../../tables/delivery-zones'

const deliveryZonesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/delivery-zones')({
  validateSearch: deliveryZonesSearchSchema,
  component: DeliveryZonesPage,
})

function DeliveryZonesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof deliveryZonesSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryZone()
  const { permissions } = usePermissions()

  const editId = search.edit
  const isCreating = !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openEdit = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })

  useRowClickBridge('data-delivery-zone-id', openEdit)

  async function handleDelete(zone: DeliveryZone) {
    const ok = await confirm({
      title: t('admin.delivery_zones.delete_confirm.title'),
      message: t('admin.delivery_zones.delete_confirm.message', { name: zone.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(zone.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<DeliveryZone>
        tableKey="delivery-zones"
        queryKey="delivery-zones"
        queryFn={(params) => adminClient.deliveryZones.list(params)}
        searchParams={search}
        rowActions={(zone) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(zone.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.DeliveryZone),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(zone),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.DeliveryZone}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.delivery_zones.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateDeliveryZoneSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditDeliveryZoneSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

function CreateDeliveryZoneSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateDeliveryZone()
  const form = useForm<DeliveryZoneFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(deliveryZoneFormSchema) as any,
    defaultValues: DELIVERY_ZONE_DEFAULTS,
  })

  async function onSubmit(values: DeliveryZoneFormValues) {
    try {
      await createMutation.mutateAsync(deliveryZoneValuesToParams(values))
      form.reset(DELIVERY_ZONE_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DELIVERY_ZONE_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.delivery_zones.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.delivery_zones.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <DeliveryZoneFormFields form={form} />
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.delivery_zones.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditDeliveryZoneSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: zone, isLoading } = useDeliveryZone(id)
  const updateMutation = useUpdateDeliveryZone(id)

  const form = useForm<DeliveryZoneFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(deliveryZoneFormSchema) as any,
    defaultValues: DELIVERY_ZONE_DEFAULTS,
  })

  useEffect(() => {
    if (zone) {
      form.reset({
        name: zone.name,
        description: zone.description ?? '',
        members: zone.members.map((member) => ({
          member_type:
            member.member_type as DeliveryZoneFormValues['members'][number]['member_type'],
          country_iso: member.country_iso ?? '',
          state_abbr: member.state_abbr ?? '',
          postal_code_prefix: member.postal_code_prefix ?? '',
          postal_code_from: member.postal_code_from ?? '',
          postal_code_to: member.postal_code_to ?? '',
        })),
      })
    }
  }, [zone, form])

  async function onSubmit(values: DeliveryZoneFormValues) {
    try {
      await updateMutation.mutateAsync(deliveryZoneValuesToParams(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{zone?.name ?? t('admin.delivery_zones.edit_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.delivery_zones.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <DeliveryZoneFormFields form={form} />
            </div>
            <SheetFooter>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}

function DeliveryZoneFormFields({ form }: { form: UseFormReturn<DeliveryZoneFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const membersArray = useFieldArray({ control: form.control, name: 'members' })

  const { data: countries } = useQuery({
    queryKey: ['countries'],
    queryFn: () => adminClient.countries.list({ limit: 300 }),
    staleTime: 1000 * 60 * 60,
  })

  const countryOptions = (countries?.data ?? []).map((country) => ({
    value: country.iso,
    label: country.name,
  }))

  const memberTypeOptions = MEMBER_TYPES.map((value) => ({
    value,
    label: t(`admin.delivery_zones.member_types.${value}`),
  }))

  return (
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
        <FieldLabel htmlFor="description">{t('admin.fields.description.label')}</FieldLabel>
        <Textarea id="description" rows={2} {...form.register('description')} />
      </Field>

      <div className="flex items-center justify-between">
        <FieldLabel>{t('admin.delivery_zones.members_column')}</FieldLabel>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() => membersArray.append({ member_type: 'country', country_iso: '' })}
        >
          <PlusIcon className="size-4" />
          {t('admin.delivery_zones.add_member')}
        </Button>
      </div>

      {membersArray.fields.length === 0 && (
        <p className="text-sm text-muted-foreground">{t('admin.delivery_zones.no_members_hint')}</p>
      )}

      {membersArray.fields.map((member, index) => {
        const memberType = form.watch(`members.${index}.member_type`)
        return (
          <div key={member.id} className="flex flex-col gap-2 rounded-md border p-3">
            <div className="flex items-center gap-2">
              <Controller
                name={`members.${index}.member_type`}
                control={form.control}
                render={({ field }) => (
                  <Select
                    items={memberTypeOptions}
                    value={field.value}
                    onValueChange={field.onChange}
                  >
                    <SelectTrigger className="flex-1">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {memberTypeOptions.map((option) => (
                        <SelectItem key={option.value} value={option.value}>
                          {option.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
              />
              <Button
                type="button"
                variant="ghost"
                size="icon-sm"
                onClick={() => membersArray.remove(index)}
                aria-label={t('admin.actions.delete')}
              >
                <Trash2Icon className="size-4" />
              </Button>
            </div>

            <Controller
              name={`members.${index}.country_iso`}
              control={form.control}
              render={({ field }) => (
                <Select
                  items={countryOptions}
                  value={field.value ?? ''}
                  onValueChange={field.onChange}
                >
                  <SelectTrigger>
                    <SelectValue>
                      {(value) =>
                        countryOptions.find((option) => option.value === value)?.label ??
                        t('admin.delivery_zones.select_country')
                      }
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    {countryOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />

            {memberType === 'state' && (
              <Input
                placeholder={t('admin.delivery_zones.state_placeholder')}
                {...form.register(`members.${index}.state_abbr`)}
              />
            )}

            {memberType === 'postal_code' && (
              <div className="grid grid-cols-3 gap-2">
                <Input
                  placeholder={t('admin.delivery_zones.prefix_placeholder')}
                  {...form.register(`members.${index}.postal_code_prefix`)}
                />
                <Input
                  placeholder={t('admin.delivery_zones.from_placeholder')}
                  {...form.register(`members.${index}.postal_code_from`)}
                />
                <Input
                  placeholder={t('admin.delivery_zones.to_placeholder')}
                  {...form.register(`members.${index}.postal_code_to`)}
                />
              </div>
            )}
          </div>
        )
      })}
    </FieldGroup>
  )
}
