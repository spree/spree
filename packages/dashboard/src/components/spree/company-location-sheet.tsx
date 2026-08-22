import { zodResolver } from '@hookform/resolvers/zod'
import type { CompanyLocation } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
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
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCreateCompanyLocation, useUpdateCompanyLocation } from '../../hooks/use-companies'
import {
  addressesMatch,
  COMPANY_LOCATION_DEFAULTS,
  type CompanyLocationFormValues,
  companyLocationFormSchema,
  companyLocationValuesToParams,
} from '../../schemas/company'
import { AddressFieldset } from './address-fieldset'

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
    country_code: address?.country_code ?? '',
    state_code: address?.state_code ?? '',
  }
}
