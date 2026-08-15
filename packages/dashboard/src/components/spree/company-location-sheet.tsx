import { zodResolver } from '@hookform/resolvers/zod'
import type { CompanyLocation } from '@spree/admin-sdk'
import {
  CountryCombobox,
  mapSpreeErrorsToForm,
  StateCombobox,
  useCountryStates,
} from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  Field,
  FieldDescription,
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
import { useCreateCompanyLocation, useUpdateCompanyLocation } from '../../hooks/use-companies'
import {
  addressesMatch,
  COMPANY_LOCATION_DEFAULTS,
  type CompanyLocationFormValues,
  companyLocationFormSchema,
  companyLocationValuesToParams,
} from '../../schemas/company'

/**
 * Creates a branch under a company, or edits one addressed by its own id. A
 * branch carries both a billing and a shipping address because the business
 * it is invoiced at is not always where the goods go.
 */
export function CompanyLocationSheet({
  companyId,
  location,
  open,
  onOpenChange,
}: {
  companyId: string
  location?: CompanyLocation
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCompanyLocation(companyId)
  const updateMutation = useUpdateCompanyLocation(location?.id ?? '', companyId)

  const form = useForm<CompanyLocationFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(companyLocationFormSchema) as any,
    defaultValues: COMPANY_LOCATION_DEFAULTS,
  })

  useEffect(() => {
    if (!open) return
    if (!location) {
      form.reset(COMPANY_LOCATION_DEFAULTS)
      return
    }

    const billing = addressToForm(location.billing_address)
    const shipping = addressToForm(location.shipping_address)
    form.reset({
      name: location.name,
      external_id: location.external_id ?? '',
      billing_address: billing,
      shipping_address: shipping,
      // A branch saved with matching addresses reopens with the box ticked, so
      // editing the billing address keeps carrying both.
      shipping_same_as_billing: addressesMatch(billing, shipping),
    })
  }, [open, location, form])

  const sameAsBilling = form.watch('shipping_same_as_billing')

  async function handleSubmit(values: CompanyLocationFormValues) {
    try {
      const params = companyLocationValuesToParams(values)
      if (location) {
        await updateMutation.mutateAsync(params)
      } else {
        await createMutation.mutateAsync(params)
      }
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  const { errors } = form.formState

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>
            {location
              ? t('admin.company_locations.edit_title')
              : t('admin.company_locations.add_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.company_locations.dialog_description')}</SheetDescription>
        </SheetHeader>
        <form
          onSubmit={(event) => {
            form.handleSubmit(handleSubmit)(event)
            event.stopPropagation()
          }}
          className="flex min-h-0 flex-1 flex-col"
        >
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}

              <Field>
                <FieldLabel htmlFor="location-name">{t('admin.fields.name.label')}</FieldLabel>
                <Input
                  id="location-name"
                  autoFocus
                  placeholder={t('admin.fields.company_location.name.placeholder')}
                  aria-invalid={!!errors.name || undefined}
                  {...form.register('name')}
                />
                <FieldError errors={[errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="location-external-id">
                  {t('admin.fields.external_id.label')}
                </FieldLabel>
                <Input id="location-external-id" {...form.register('external_id')} />
                <FieldDescription>
                  {t('admin.fields.company_location.external_id.help')}
                </FieldDescription>
              </Field>

              <AddressFieldset
                form={form}
                prefix="billing_address"
                legend={t('admin.company_locations.billing_address')}
              />

              <Controller
                name="shipping_same_as_billing"
                control={form.control}
                render={({ field }) => (
                  <label
                    htmlFor="shipping-same-as-billing"
                    className="flex cursor-pointer items-center gap-2 text-sm"
                  >
                    <Checkbox
                      id="shipping-same-as-billing"
                      checked={!!field.value}
                      onCheckedChange={field.onChange}
                    />
                    {t('admin.company_locations.shipping_same_as_billing')}
                  </label>
                )}
              />

              {!sameAsBilling && (
                <AddressFieldset
                  form={form}
                  prefix="shipping_address"
                  legend={t('admin.company_locations.shipping_address')}
                />
              )}
            </FieldGroup>
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
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function addressToForm(address: CompanyLocation['billing_address'] | undefined) {
  return {
    first_name: address?.first_name ?? '',
    last_name: address?.last_name ?? '',
    company: address?.company ?? '',
    address1: address?.address1 ?? '',
    address2: address?.address2 ?? '',
    city: address?.city ?? '',
    postal_code: address?.postal_code ?? '',
    phone: address?.phone ?? '',
    country_iso: address?.country_iso ?? '',
    state_code: address?.state_code ?? '',
  }
}

function AddressFieldset({
  form,
  prefix,
  legend,
}: {
  form: UseFormReturn<CompanyLocationFormValues>
  prefix: 'billing_address' | 'shipping_address'
  legend: string
}) {
  const { t } = useTranslation()
  const countryIso = form.watch(`${prefix}.country_iso`)
  const { states } = useCountryStates(countryIso)

  return (
    <fieldset className="flex flex-col gap-4 rounded-md border p-4">
      <legend className="px-1 font-medium text-sm">{legend}</legend>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor={`${prefix}-first-name`}>
            {t('admin.fields.first_name.label')}
          </FieldLabel>
          <Input id={`${prefix}-first-name`} {...form.register(`${prefix}.first_name`)} />
        </Field>
        <Field>
          <FieldLabel htmlFor={`${prefix}-last-name`}>
            {t('admin.fields.last_name.label')}
          </FieldLabel>
          <Input id={`${prefix}-last-name`} {...form.register(`${prefix}.last_name`)} />
        </Field>
      </div>

      <Field>
        <FieldLabel htmlFor={`${prefix}-address1`}>{t('admin.fields.address1.label')}</FieldLabel>
        <Input id={`${prefix}-address1`} {...form.register(`${prefix}.address1`)} />
      </Field>

      <Field>
        <FieldLabel htmlFor={`${prefix}-address2`}>{t('admin.fields.address2.label')}</FieldLabel>
        <Input id={`${prefix}-address2`} {...form.register(`${prefix}.address2`)} />
      </Field>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor={`${prefix}-city`}>{t('admin.fields.city.label')}</FieldLabel>
          <Input id={`${prefix}-city`} {...form.register(`${prefix}.city`)} />
        </Field>
        <Field>
          <FieldLabel htmlFor={`${prefix}-postal-code`}>
            {t('admin.fields.postal_code.label')}
          </FieldLabel>
          <Input id={`${prefix}-postal-code`} {...form.register(`${prefix}.postal_code`)} />
        </Field>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor={`${prefix}-country`}>{t('admin.fields.country.label')}</FieldLabel>
          <Controller
            name={`${prefix}.country_iso`}
            control={form.control}
            render={({ field }) => (
              <CountryCombobox
                value={field.value}
                onValueChange={(iso) => {
                  field.onChange(iso)
                  form.setValue(`${prefix}.state_code`, '', { shouldDirty: true })
                }}
              />
            )}
          />
        </Field>
        {countryIso && states.length > 0 && (
          <Field>
            <FieldLabel htmlFor={`${prefix}-state`}>{t('admin.fields.state.label')}</FieldLabel>
            <Controller
              name={`${prefix}.state_code`}
              control={form.control}
              render={({ field }) => (
                <StateCombobox
                  countryIso={countryIso}
                  states={states}
                  value={field.value}
                  onValueChange={field.onChange}
                />
              )}
            />
          </Field>
        )}
      </div>

      <Field>
        <FieldLabel htmlFor={`${prefix}-phone`}>{t('admin.fields.phone.label')}</FieldLabel>
        <Input id={`${prefix}-phone`} {...form.register(`${prefix}.phone`)} />
      </Field>
    </fieldset>
  )
}
