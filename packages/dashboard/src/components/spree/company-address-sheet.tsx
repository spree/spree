import { zodResolver } from '@hookform/resolvers/zod'
import type { Address } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
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
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCreateCompanyAddress, useUpdateCompanyAddress } from '../../hooks/use-companies'
import {
  COMPANY_ADDRESS_DEFAULTS,
  type CompanyAddressFormValues,
  companyAddressFormSchema,
  companyAddressValuesToParams,
} from '../../schemas/company'
import { AddressFieldset } from './address-fieldset'

/**
 * Creates an entry in a company node's address book, or edits one. The entry
 * owns its address row outright; promoting it to a default demotes the prior
 * default of the same kind.
 */
export function CompanyAddressSheet({
  companyId,
  entry,
  open,
  onOpenChange,
}: {
  companyId: string
  entry?: Address
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateCompanyAddress(companyId)
  const updateMutation = useUpdateCompanyAddress(companyId)

  const form = useForm<CompanyAddressFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(companyAddressFormSchema) as any,
    defaultValues: COMPANY_ADDRESS_DEFAULTS,
  })

  useEffect(() => {
    if (!open) return
    if (!entry) {
      form.reset(COMPANY_ADDRESS_DEFAULTS)
      return
    }

    form.reset({
      label: entry.label ?? '',
      default_billing: entry.is_default_billing,
      default_shipping: entry.is_default_shipping,
      first_name: entry.first_name ?? '',
      last_name: entry.last_name ?? '',
      company: entry.company ?? '',
      address1: entry.address1 ?? '',
      address2: entry.address2 ?? '',
      city: entry.city ?? '',
      postal_code: entry.postal_code ?? '',
      phone: entry.phone ?? '',
      country_code: entry.country_code ?? '',
      state_code: entry.state_code ?? '',
    })
  }, [open, entry, form])

  async function onSubmit(values: CompanyAddressFormValues) {
    try {
      const params = companyAddressValuesToParams(values)
      if (entry) {
        await updateMutation.mutateAsync({ id: entry.id, params })
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
      <SheetContent className="sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>
            {entry
              ? t('admin.company_addresses.edit_sheet_title')
              : t('admin.company_addresses.add_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.company_addresses.sheet_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <FieldGroup>
              {errors.root?.message && (
                <p className="text-destructive text-sm" role="alert">
                  {errors.root.message}
                </p>
              )}

              <Field>
                <FieldLabel htmlFor="company-address-label">
                  {t('admin.fields.company_address.label.label')}
                </FieldLabel>
                <Input
                  id="company-address-label"
                  autoFocus
                  placeholder={t('admin.fields.company_address.label.placeholder')}
                  aria-invalid={!!errors.label || undefined}
                  {...form.register('label')}
                />
                <FieldDescription>{t('admin.fields.company_address.label.help')}</FieldDescription>
                <FieldError errors={[errors.label]} />
              </Field>

              <AddressFieldset form={form} legend={t('admin.company_addresses.address_legend')} />

              <Controller
                control={form.control}
                name="default_billing"
                render={({ field }) => (
                  <label
                    htmlFor="company-address-default-billing"
                    className="flex items-center gap-2 text-sm"
                  >
                    <Checkbox
                      id="company-address-default-billing"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                    {t('admin.company_addresses.default_billing_label')}
                  </label>
                )}
              />
              <Controller
                control={form.control}
                name="default_shipping"
                render={({ field }) => (
                  <label
                    htmlFor="company-address-default-shipping"
                    className="flex items-center gap-2 text-sm"
                  >
                    <Checkbox
                      id="company-address-default-shipping"
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                    {t('admin.company_addresses.default_shipping_label')}
                  </label>
                )}
              />
            </FieldGroup>
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
            <Button type="submit" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
