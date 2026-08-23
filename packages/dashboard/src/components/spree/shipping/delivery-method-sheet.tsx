import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryProfile, DeliveryZone } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  useCreateDeliveryMethod,
  useDeliveryMethod,
  useDeliveryMethodRuleTypes,
  useFulfillmentProviders,
  useUpdateDeliveryMethod,
} from '../../../hooks/use-delivery-methods'
import {
  DELIVERY_METHOD_DEFAULTS,
  type DeliveryMethodFormValues,
  deliveryMethodFormSchema,
  deliveryMethodValuesToParams,
} from '../../../schemas/delivery-method'
import { DeliveryMethodFormCards } from './delivery-method-form'

/** API decimals arrive as strings ("0.0"); show blank instead of a noisy zero. */
function decimalToForm(value: string | null | undefined) {
  if (value === null || value === undefined || value === '') return ''
  return Number(value) === 0 ? '' : String(value)
}

/** Whether a rule kind is configured with a product list rather than preferences. */
function takesProducts(
  ruleTypes: { type: string; association_fields: string[] }[] | undefined,
  type: string,
) {
  return (
    ruleTypes?.find((candidate) => candidate.type === type)?.association_fields ?? []
  ).includes('product_ids')
}

/**
 * Creates or edits one delivery method. Methods are managed from the profile
 * page that owns them, so the profile always comes from the page that opened
 * this sheet and stays visible behind it.
 */
export function DeliveryMethodSheet({
  profile,
  zones,
  methodId,
  zoneId,
  originGroupId,
  provider,
  open,
  onOpenChange,
}: {
  profile: DeliveryProfile
  zones: DeliveryZone[]
  /** Absent when creating a new method. */
  methodId?: string
  /** Preselects the zone the merchant clicked "Add method" inside. Create only. */
  zoneId?: string
  /**
   * Files the new method under the origin group it was added from, which
   * matters only once a profile has been split into several. Create only.
   */
  originGroupId?: string
  /**
   * The kind of fulfillment the merchant asked for, so "Offer pickup" opens a
   * sheet already set up for a counter. Create only.
   */
  provider?: 'pickup' | 'digital'
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const editing = !!methodId

  const { data: method, isLoading: methodLoading } = useDeliveryMethod(methodId)
  const { data: ruleTypes, isLoading: ruleTypesLoading } = useDeliveryMethodRuleTypes()
  const { data: fulfillmentProviders } = useFulfillmentProviders()
  const createMutation = useCreateDeliveryMethod()
  const updateMutation = useUpdateDeliveryMethod(methodId ?? '')

  // Saving sends the full rule set for reconciliation, so the form must not be
  // reachable until the existing rules have loaded — otherwise a quick save
  // would submit an empty set and delete them all. Rule types are needed too,
  // since they decide which rules carry a product list.
  const loading = editing ? methodLoading || ruleTypesLoading : ruleTypesLoading

  const form = useForm<DeliveryMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(deliveryMethodFormSchema) as any,
    defaultValues: { ...DELIVERY_METHOD_DEFAULTS, delivery_zone_id: zoneId ?? '' },
  })

  useEffect(() => {
    if (!editing) {
      form.reset({ ...DELIVERY_METHOD_DEFAULTS, delivery_zone_id: zoneId ?? '' })
      return
    }
    // Wait for rule types too — seeding the form before they arrive would
    // reset again once they land, discarding anything already edited.
    if (!method || !ruleTypes) return

    form.reset({
      name: method.name,
      admin_name: method.admin_name ?? '',
      code: method.code ?? '',
      fulfillment_provider:
        method.fulfillment_provider ?? DELIVERY_METHOD_DEFAULTS.fulfillment_provider,
      rate_provider: method.rate_provider ?? DELIVERY_METHOD_DEFAULTS.rate_provider,
      storefront_visible: method.storefront_visible,
      tracking_url: method.tracking_url ?? '',
      estimated_transit_business_days_min:
        method.estimated_transit_business_days_min?.toString() ?? '',
      estimated_transit_business_days_max:
        method.estimated_transit_business_days_max?.toString() ?? '',
      tax_category_id: method.tax_category_id ?? '',
      calculator_type: method.calculator_type ?? '',
      calculator_preferences: (method.calculator_preferences as Record<string, unknown>) ?? {},
      delivery_zone_id: method.delivery_zone_id ?? '',
      stock_location_ids: method.stock_location_ids ?? [],
      markup_flat: decimalToForm(method.markup_flat),
      markup_percent: decimalToForm(method.markup_percent),
      services: (method.services ?? []).map((row) => ({
        id: row.id,
        carrier: row.carrier,
        service: row.service,
        label: row.label ?? '',
        markup_flat: decimalToForm(row.markup_flat),
        markup_percent: decimalToForm(row.markup_percent),
      })),
      rules: (method.rules ?? []).map((rule) => ({
        id: rule.id,
        type: rule.type,
        preferences: rule.preferences as Record<string, unknown>,
        product_ids: rule.product_ids,
        takes_products: takesProducts(ruleTypes?.data, rule.type),
      })),
    })
  }, [editing, method, ruleTypes, zoneId, form])

  // The merchant arrived by asking for a specific kind of fulfillment
  // ("Offer pickup"), so select the provider that does it as soon as the
  // catalog arrives — leaving the field alone once they have touched it.
  const providerDirty = !!form.formState.dirtyFields.fulfillment_provider
  useEffect(() => {
    if (editing || !provider || providerDirty) return

    const match = (fulfillmentProviders?.data ?? []).find(
      (candidate) => candidate.available && candidate[provider],
    )
    if (match) form.setValue('fulfillment_provider', match.type)
  }, [editing, provider, providerDirty, fulfillmentProviders, form])

  async function onSubmit(values: DeliveryMethodFormValues) {
    try {
      if (editing) {
        await updateMutation.mutateAsync(deliveryMethodValuesToParams(values))
      } else {
        await createMutation.mutateAsync({
          ...deliveryMethodValuesToParams(values),
          delivery_profile_id: profile.id,
          // Only sent when the merchant added the method from a specific
          // group; otherwise the server files it under the zone's group, else
          // the profile's default one.
          ...(originGroupId ? { delivery_origin_group_id: originGroupId } : {}),
        })
      }
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>
            {editing
              ? (method?.name ?? t('admin.delivery_methods.edit_sheet_title'))
              : t('admin.delivery_methods.add_sheet_title')}
          </SheetTitle>
          <SheetDescription>{profile.name}</SheetDescription>
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
              <DeliveryMethodFormCards
                form={form}
                profile={profile}
                zones={zones}
                // Creating from inside a zone card answers the zone question;
                // editing still needs the picker to move a method or clear it.
                zonePreselected={!methodId && !!zoneId}
              />
            </div>
            <SheetFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="submit"
                disabled={form.formState.isSubmitting || (editing && !form.formState.isDirty)}
              >
                {form.formState.isSubmitting
                  ? editing
                    ? t('admin.actions.saving')
                    : t('admin.actions.creating')
                  : editing
                    ? t('admin.actions.save')
                    : t('admin.delivery_methods.create_label')}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}
