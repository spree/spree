import { zodResolver } from '@hookform/resolvers/zod'
import type { Address } from '@spree/admin-sdk'
import {
  Button,
  Checkbox,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  requiredMessage,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useEffect, useRef } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { mapSpreeErrorsToForm } from '../lib/form-errors'
import { CountryCombobox } from './country-combobox'
import { StateCombobox, useCountryStates } from './country-state-fields'

export interface AddressParams {
  first_name: string
  last_name: string
  address1: string
  address2: string
  city: string
  postal_code: string
  country_iso: string
  state_abbr: string
  phone: string
  label?: string
  is_default_billing?: boolean
  is_default_shipping?: boolean
}

const addressFormSchema = z.object({
  first_name: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('first_name') }),
  last_name: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('last_name') }),
  address1: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('address.address1') }),
  address2: z.string(),
  city: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('city') }),
  postal_code: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('address.postal_code') }),
  country_iso: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('country_iso') }),
  state_abbr: z.string(),
  phone: z.string(),
  label: z.string(),
  is_default_billing: z.boolean(),
  is_default_shipping: z.boolean(),
})

type AddressFormValues = z.infer<typeof addressFormSchema>

function buildDefaults(address: Address | null | undefined): AddressFormValues {
  return {
    first_name: address?.first_name ?? '',
    last_name: address?.last_name ?? '',
    address1: address?.address1 ?? '',
    address2: address?.address2 ?? '',
    city: address?.city ?? '',
    postal_code: address?.postal_code ?? '',
    country_iso: address?.country_iso ?? '',
    state_abbr: address?.state_abbr ?? '',
    phone: address?.phone ?? '',
    label: address?.label ?? '',
    is_default_billing: address?.is_default_billing ?? false,
    is_default_shipping: address?.is_default_shipping ?? false,
  }
}

export function AddressFormDialog({
  address,
  open,
  onOpenChange,
  onSave,
  title,
  isPending = false,
  showLabel = false,
  showDefaultFlags = false,
}: {
  address: Address | null | undefined
  open: boolean
  onOpenChange: (open: boolean) => void
  onSave: (address: AddressParams) => void | Promise<void>
  title?: string
  isPending?: boolean
  showLabel?: boolean
  showDefaultFlags?: boolean
}) {
  const { t } = useTranslation()
  const resolvedTitle = title ?? t('admin.components.address_form_dialog.edit_title')
  const form = useForm<AddressFormValues>({
    defaultValues: buildDefaults(address),
    resolver: zodResolver(addressFormSchema),
  })
  const { errors } = form.formState

  // The parent keys the dialog on the address id so a fresh instance mounts
  // for each open, but `address` can also stream in async (loaded after the
  // sheet mounts). Reset only when the *record identity* changes — otherwise a
  // re-render that creates a new `address` object literal would clobber edits
  // mid-flow.
  const prevAddressIdRef = useRef<string | null | undefined>(address?.id)
  useEffect(() => {
    if (address?.id !== prevAddressIdRef.current) {
      prevAddressIdRef.current = address?.id
      form.reset(buildDefaults(address))
    }
  }, [address, form])

  const countryIso = form.watch('country_iso')
  const { states, statesRequired } = useCountryStates(countryIso)
  const useStateCombobox = statesRequired && states.length > 0

  async function onSubmit(values: AddressFormValues) {
    try {
      await onSave({
        first_name: values.first_name,
        last_name: values.last_name,
        address1: values.address1,
        address2: values.address2,
        city: values.city,
        postal_code: values.postal_code,
        country_iso: values.country_iso,
        state_abbr: values.state_abbr,
        phone: values.phone,
        ...(showLabel && { label: values.label || undefined }),
        ...(showDefaultFlags && {
          is_default_billing: values.is_default_billing,
          is_default_shipping: values.is_default_shipping,
        }),
      })
    } catch (err) {
      // Surface server-side 422 validation errors on the matching fields so
      // the dialog reflects whatever the API rejected (e.g. "phone is too
      // short"). Non-validation errors bubble to the parent's toast.
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  // Prevent Enter in combobox inputs from submitting the form. RHF's
  // handleSubmit fires on submit events, so swallow Enter inside any
  // role=combobox before it bubbles into the form.
  function handleKeyDown(e: React.KeyboardEvent) {
    const target = e.target as HTMLElement
    if (e.key === 'Enter' && target.getAttribute('role') === 'combobox') {
      e.preventDefault()
    }
  }

  return (
    <Sheet open={open} onOpenChange={(o) => onOpenChange(o as boolean)}>
      <SheetContent side="right">
        <SheetHeader>
          <SheetTitle>{resolvedTitle}</SheetTitle>
          <SheetDescription>
            {t('admin.components.address_form_dialog.description')}
          </SheetDescription>
        </SheetHeader>
        <form
          onSubmit={form.handleSubmit(onSubmit)}
          onKeyDown={handleKeyDown}
          className="flex flex-col flex-1 overflow-hidden"
        >
          <div className="flex-1 overflow-y-auto p-4">
            <FieldGroup>
              {showLabel && (
                <Field>
                  <FieldLabel htmlFor="addr-label">
                    {t('admin.fields.address.label.label')}
                  </FieldLabel>
                  <Input
                    id="addr-label"
                    placeholder={t('admin.fields.address.label.placeholder')}
                    {...form.register('label')}
                  />
                </Field>
              )}
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="addr-fn">{t('admin.fields.first_name.label')}</FieldLabel>
                  <Input
                    id="addr-fn"
                    aria-invalid={!!errors.first_name || undefined}
                    {...form.register('first_name')}
                  />
                  <FieldError errors={[errors.first_name]} />
                </Field>
                <Field>
                  <FieldLabel htmlFor="addr-ln">{t('admin.fields.last_name.label')}</FieldLabel>
                  <Input
                    id="addr-ln"
                    aria-invalid={!!errors.last_name || undefined}
                    {...form.register('last_name')}
                  />
                  <FieldError errors={[errors.last_name]} />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="addr-a1">
                  {t('admin.fields.address.address1.label')}
                </FieldLabel>
                <Input
                  id="addr-a1"
                  aria-invalid={!!errors.address1 || undefined}
                  {...form.register('address1')}
                />
                <FieldError errors={[errors.address1]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="addr-a2">
                  {t('admin.fields.address.address2.label')}
                </FieldLabel>
                <Input
                  id="addr-a2"
                  aria-invalid={!!errors.address2 || undefined}
                  {...form.register('address2')}
                />
                <FieldError errors={[errors.address2]} />
              </Field>
              <Field>
                <FieldLabel>{t('admin.fields.country_iso.label')}</FieldLabel>
                <Controller
                  name="country_iso"
                  control={form.control}
                  render={({ field }) => (
                    <CountryCombobox
                      value={field.value}
                      onValueChange={(iso) => {
                        field.onChange(iso)
                        form.setValue('state_abbr', '', { shouldDirty: true })
                      }}
                    />
                  )}
                />
                <FieldError errors={[errors.country_iso]} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="addr-city">{t('admin.fields.city.label')}</FieldLabel>
                  <Input
                    id="addr-city"
                    aria-invalid={!!errors.city || undefined}
                    {...form.register('city')}
                  />
                  <FieldError errors={[errors.city]} />
                </Field>
                {useStateCombobox ? (
                  <Field>
                    <FieldLabel>{t('admin.fields.state_abbr.label')}</FieldLabel>
                    <Controller
                      name="state_abbr"
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
                    <FieldError errors={[errors.state_abbr]} />
                  </Field>
                ) : (
                  <Field>
                    <FieldLabel htmlFor="addr-state-abbr">
                      {t('admin.fields.state_abbr.label')}
                    </FieldLabel>
                    <Input
                      id="addr-state-abbr"
                      aria-invalid={!!errors.state_abbr || undefined}
                      {...form.register('state_abbr')}
                    />
                    <FieldError errors={[errors.state_abbr]} />
                  </Field>
                )}
              </div>
              <Field>
                <FieldLabel htmlFor="addr-zip">
                  {t('admin.fields.address.postal_code.label')}
                </FieldLabel>
                <Input
                  id="addr-zip"
                  aria-invalid={!!errors.postal_code || undefined}
                  {...form.register('postal_code')}
                />
                <FieldError errors={[errors.postal_code]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="addr-phone">{t('admin.fields.phone.label')}</FieldLabel>
                <Input
                  id="addr-phone"
                  aria-invalid={!!errors.phone || undefined}
                  {...form.register('phone')}
                />
                <FieldError errors={[errors.phone]} />
              </Field>
              {showDefaultFlags && (
                <>
                  <Field>
                    <div className="flex items-start justify-between gap-4">
                      <FieldLabel htmlFor="addr-default-billing" className="cursor-pointer">
                        {t('admin.fields.address.is_default_billing.label')}
                      </FieldLabel>
                      <Controller
                        name="is_default_billing"
                        control={form.control}
                        render={({ field }) => (
                          <Checkbox
                            id="addr-default-billing"
                            checked={!!field.value}
                            onCheckedChange={field.onChange}
                          />
                        )}
                      />
                    </div>
                  </Field>
                  <Field>
                    <div className="flex items-start justify-between gap-4">
                      <FieldLabel htmlFor="addr-default-shipping" className="cursor-pointer">
                        {t('admin.fields.address.is_default_shipping.label')}
                      </FieldLabel>
                      <Controller
                        name="is_default_shipping"
                        control={form.control}
                        render={({ field }) => (
                          <Checkbox
                            id="addr-default-shipping"
                            checked={!!field.value}
                            onCheckedChange={field.onChange}
                          />
                        )}
                      />
                    </div>
                  </Field>
                </>
              )}
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={isPending}>
              {isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}
