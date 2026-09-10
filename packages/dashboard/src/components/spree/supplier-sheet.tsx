import type { Supplier } from '@spree/admin-sdk'
import { CountryCombobox, StateCombobox, useCountryStates } from '@spree/dashboard-core'
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
  Textarea,
} from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useCreateSupplier, useSupplier, useUpdateSupplier } from '../../hooks/use-suppliers'

interface SupplierFormState {
  name: string
  contact_name: string
  email: string
  phone: string
  notes: string
  address1: string
  address2: string
  city: string
  state_name: string
  state_code: string
  country_code: string
  postal_code: string
}

const EMPTY_FORM: SupplierFormState = {
  name: '',
  contact_name: '',
  email: '',
  phone: '',
  notes: '',
  address1: '',
  address2: '',
  city: '',
  state_name: '',
  state_code: '',
  country_code: '',
  postal_code: '',
}

/**
 * Create or correct a supplier, wherever the merchant needs one.
 *
 * The purchase order screen opens it too: buying from someone new is part of
 * raising the order, not a detour through another screen.
 */
export function SupplierSheet({
  id,
  open,
  onOpenChange,
  onCreated,
}: {
  id?: string
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Handed the new record, so a caller can select what it just created. */
  onCreated?: (supplier: Supplier) => void
}) {
  const { t } = useTranslation()
  const { data: supplier } = useSupplier(id)
  const createMutation = useCreateSupplier()
  const updateMutation = useUpdateSupplier(id ?? '')
  const mutation = id ? updateMutation : createMutation

  const [form, setForm] = useState<SupplierFormState>(EMPTY_FORM)
  const [hydratedFor, setHydratedFor] = useState<string | undefined>(undefined)
  // A blank name is only wrong once the merchant has tried to save; showing it
  // on a sheet they just opened reads as an error they caused.
  const [submitAttempted, setSubmitAttempted] = useState(false)
  const { states } = useCountryStates(form.country_code)

  // The record arrives after the sheet opens, so seed the fields the first
  // time it does rather than on every render.
  if (supplier && hydratedFor !== supplier.id) {
    setHydratedFor(supplier.id)
    setForm({
      name: supplier.name,
      contact_name: supplier.contact_name ?? '',
      email: supplier.email ?? '',
      phone: supplier.phone ?? '',
      notes: supplier.notes ?? '',
      address1: supplier.address1 ?? '',
      address2: supplier.address2 ?? '',
      city: supplier.city ?? '',
      state_name: supplier.state_name ?? '',
      state_code: supplier.state_code ?? '',
      country_code: supplier.country_code ?? '',
      postal_code: supplier.postal_code ?? '',
    })
  }

  function set<K extends keyof SupplierFormState>(key: K, value: SupplierFormState[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  async function handleSubmit() {
    setSubmitAttempted(true)
    if (!form.name.trim()) return

    // Emptied fields are sent as null, not dropped: the API reads a missing
    // key as "leave it alone", so dropping them would make a cleared phone
    // number come back on the next fetch.
    const payload = Object.fromEntries(
      Object.entries(form).map(([key, value]) => [key, value.trim() || null]),
    ) as Record<string, string | null>

    const saved = await mutation
      .mutateAsync({ ...payload, name: form.name.trim() })
      .catch(() => undefined)
    if (!saved) return

    if (!id) onCreated?.(saved)
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="sm:max-w-xl">
        <SheetHeader>
          <SheetTitle>
            {id ? t('admin.suppliers.edit_title') : t('admin.suppliers.new_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.suppliers.sheet_description')}</SheetDescription>
        </SheetHeader>

        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="supplier-name">{t('admin.fields.name.label')}</FieldLabel>
              <Input
                id="supplier-name"
                value={form.name}
                onChange={(event) => set('name', event.target.value)}
                aria-invalid={(submitAttempted && !form.name.trim()) || undefined}
              />
              {submitAttempted && !form.name.trim() && (
                <FieldError>{t('admin.suppliers.errors.name_blank')}</FieldError>
              )}
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-contact">
                {t('admin.suppliers.fields.contact_name')}
              </FieldLabel>
              <Input
                id="supplier-contact"
                value={form.contact_name}
                onChange={(event) => set('contact_name', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-email">{t('admin.fields.email.label')}</FieldLabel>
              <Input
                id="supplier-email"
                type="email"
                value={form.email}
                onChange={(event) => set('email', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-phone">{t('admin.fields.phone.label')}</FieldLabel>
              <Input
                id="supplier-phone"
                value={form.phone}
                onChange={(event) => set('phone', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-address1">
                {t('admin.suppliers.fields.address1')}
              </FieldLabel>
              <Input
                id="supplier-address1"
                value={form.address1}
                onChange={(event) => set('address1', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-address2">
                {t('admin.suppliers.fields.address2')}
              </FieldLabel>
              <Input
                id="supplier-address2"
                value={form.address2}
                onChange={(event) => set('address2', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-city">{t('admin.suppliers.fields.city')}</FieldLabel>
              <Input
                id="supplier-city"
                value={form.city}
                onChange={(event) => set('city', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-postal-code">
                {t('admin.suppliers.fields.postal_code')}
              </FieldLabel>
              <Input
                id="supplier-postal-code"
                value={form.postal_code}
                onChange={(event) => set('postal_code', event.target.value)}
              />
            </Field>

            <Field>
              <FieldLabel htmlFor="supplier-country">{t('admin.fields.country.label')}</FieldLabel>
              <CountryCombobox
                id="supplier-country"
                value={form.country_code}
                onValueChange={(iso) => {
                  set('country_code', iso ?? '')
                  // The old state belongs to the old country; keeping it would
                  // put the supplier in a state that no longer exists.
                  set('state_code', '')
                }}
              />
            </Field>

            {form.country_code && states.length > 0 && (
              <Field>
                <FieldLabel htmlFor="supplier-state">{t('admin.fields.state.label')}</FieldLabel>
                <StateCombobox
                  id="supplier-state"
                  countryCode={form.country_code}
                  states={states}
                  value={form.state_code}
                  onValueChange={(abbr) => set('state_code', abbr)}
                />
              </Field>
            )}

            <Field>
              <FieldLabel htmlFor="supplier-notes">{t('admin.suppliers.fields.notes')}</FieldLabel>
              <Textarea
                id="supplier-notes"
                value={form.notes}
                onChange={(event) => set('notes', event.target.value)}
              />
            </Field>
          </FieldGroup>
        </div>

        <SheetFooter>
          <Button
            type="button"
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={mutation.isPending}
          >
            {t('admin.actions.cancel')}
          </Button>
          {/* Clickable with the name still blank: pressing Save is how the
              merchant asks what is missing, and a button that only greys out
              never says. */}
          <Button type="button" onClick={handleSubmit} disabled={mutation.isPending}>
            {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
