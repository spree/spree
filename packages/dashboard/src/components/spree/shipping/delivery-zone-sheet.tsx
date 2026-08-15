import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryZone } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  useCreateDeliveryZone,
  useDeliveryZone,
  useUpdateDeliveryZone,
} from '../../../hooks/use-delivery-zones'
import {
  DELIVERY_ZONE_DEFAULTS,
  type DeliveryZoneFormValues,
  deliveryZoneFormSchema,
  deliveryZoneValuesToParams,
} from '../../../schemas/delivery-zone'
import { DeliveryZoneRegionPicker } from './delivery-zone-region-picker'

/**
 * Creates or edits one delivery zone. Zones are managed inside the profile
 * that owns them and never move between profiles, so the profile always
 * comes from the page that opened this sheet.
 */
export function DeliveryZoneSheet({
  deliveryProfileId,
  deliveryOriginGroupId,
  zoneId,
  siblingZones = [],
  open,
  onOpenChange,
}: {
  deliveryProfileId: string
  /**
   * Origin group the new zone hangs off. Only sent on create — a zone never
   * moves between groups, and the server files it under the profile's default
   * group when omitted.
   */
  deliveryOriginGroupId?: string
  /** Absent when creating a new zone. */
  zoneId?: string
  /**
   * The profile's other zones, members included. A country served by one zone
   * cannot be served by another, so those rows are shown but locked.
   */
  siblingZones?: DeliveryZone[]
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: zone, isLoading } = useDeliveryZone(zoneId)
  const createMutation = useCreateDeliveryZone()
  const updateMutation = useUpdateDeliveryZone(zoneId ?? '')

  const form = useForm<DeliveryZoneFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(deliveryZoneFormSchema) as any,
    defaultValues: DELIVERY_ZONE_DEFAULTS,
  })

  useEffect(() => {
    if (!zoneId) {
      form.reset(DELIVERY_ZONE_DEFAULTS)
      return
    }
    if (!zone) return

    form.reset({
      name: zone.name,
      // No longer edited in this sheet, but carried through the form so
      // saving never blanks a description an older zone already has.
      description: zone.description ?? '',
      // `useDeliveryZone` expands members; without them the picker would come
      // up empty and saving would wipe the zone's real coverage.
      members: (zone.members ?? []).map((member) => ({
        member_type: member.member_type as DeliveryZoneFormValues['members'][number]['member_type'],
        country_code: member.country_code ?? '',
        state_code: member.state_code ?? '',
        postal_code_prefix: member.postal_code_prefix ?? '',
        postal_code_from: member.postal_code_from ?? '',
        postal_code_to: member.postal_code_to ?? '',
      })),
    })
  }, [zone, zoneId, form])

  async function onSubmit(values: DeliveryZoneFormValues) {
    try {
      if (zoneId) {
        await updateMutation.mutateAsync(deliveryZoneValuesToParams(values))
      } else {
        await createMutation.mutateAsync(
          deliveryZoneValuesToParams(values, deliveryProfileId, deliveryOriginGroupId),
        )
      }
      form.reset(zoneId ? values : DELIVERY_ZONE_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const editing = !!zoneId
  const loading = editing && isLoading

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next && !editing) form.reset(DELIVERY_ZONE_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {editing
              ? (zone?.name ?? t('admin.delivery_zones.edit_sheet_title'))
              : t('admin.delivery_zones.add_sheet_title')}
          </SheetTitle>
          <SheetDescription>
            {editing
              ? t('admin.delivery_zones.edit_description')
              : t('admin.delivery_zones.create_description')}
          </SheetDescription>
        </SheetHeader>
        {loading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form
            onSubmit={(event) => {
              // This sheet renders inside the profile page's cards, which sit
              // in their own forms — without stopping the bubble the browser
              // would submit the outer one instead.
              form.handleSubmit(onSubmit)(event)
              event.stopPropagation()
            }}
            className="flex min-h-0 flex-1 flex-col"
          >
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <DeliveryZoneFormFields
                form={form}
                siblingZones={siblingZones.filter((sibling) => sibling.id !== zoneId)}
              />
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
                disabled={form.formState.isSubmitting || (editing && !form.formState.isDirty)}
              >
                {form.formState.isSubmitting
                  ? editing
                    ? t('admin.actions.saving')
                    : t('admin.actions.creating')
                  : editing
                    ? t('admin.actions.save')
                    : t('admin.delivery_zones.create_label')}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}

function DeliveryZoneFormFields({
  form,
  siblingZones,
}: {
  form: UseFormReturn<DeliveryZoneFormValues>
  siblingZones: DeliveryZone[]
}) {
  const { t } = useTranslation()
  const { errors } = form.formState

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

      <Controller
        name="members"
        control={form.control}
        render={({ field }) => (
          <DeliveryZoneRegionPicker
            value={field.value}
            onChange={field.onChange}
            siblingZones={siblingZones}
          />
        )}
      />
    </FieldGroup>
  )
}
