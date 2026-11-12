import type { Supplier } from '@spree/admin-sdk'
import { CountryCombobox, StateCombobox, useCountryStates } from '@spree/dashboard-core'
import { Field, FieldError, FieldGroup, FieldLabel, Input, Textarea } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

export interface SupplierFormState {
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

/** The two halves of a supplier the page edits in separate cards. */
export const SUPPLIER_PARTS = {
  details: ['name', 'contact_name', 'email', 'phone', 'notes'],
  address: [
    'address1',
    'address2',
    'city',
    'postal_code',
    'country_code',
    'state_code',
    'state_name',
  ],
} as const satisfies Record<string, readonly (keyof SupplierFormState)[]>

export type SupplierFormPart = keyof typeof SUPPLIER_PARTS

function formFor(supplier: Supplier): SupplierFormState {
  return {
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
  }
}

/**
 * A supplier's editable fields, for the create/edit sheet and the supplier's
 * page. `save` hands the payload to `persist` and resolves to the saved record,
 * or `undefined` when the name is blank or the write failed.
 */
export function useSupplierForm(
  supplier: Supplier | undefined,
  persist: (payload: Record<string, string | null>) => Promise<Supplier>,
  /**
   * Limits the form to one half: only its fields are sent and compared. Two
   * cards each sending the whole record would let one card's save put back
   * what the other just changed.
   */
  part?: SupplierFormPart,
) {
  const keys: readonly (keyof SupplierFormState)[] = part
    ? SUPPLIER_PARTS[part]
    : (Object.keys(EMPTY_FORM) as (keyof SupplierFormState)[])
  const [form, setForm] = useState<SupplierFormState>(EMPTY_FORM)
  const [saved, setSaved] = useState<SupplierFormState>(EMPTY_FORM)
  const [hydratedFor, setHydratedFor] = useState<string | undefined>(undefined)
  // A blank name is only wrong once the merchant has tried to save; showing it
  // on a form they just opened reads as an error they caused.
  const [submitAttempted, setSubmitAttempted] = useState(false)

  // The record arrives after the form mounts, so seed the fields the first
  // time it does rather than on every render.
  if (supplier && hydratedFor !== supplier.id) {
    setHydratedFor(supplier.id)
    setForm(formFor(supplier))
    setSaved(formFor(supplier))
  }

  function set<K extends keyof SupplierFormState>(key: K, value: SupplierFormState[K]) {
    setForm((prev) => ({ ...prev, [key]: value }))
  }

  async function save() {
    setSubmitAttempted(true)
    if (keys.includes('name') && !form.name.trim()) return undefined

    // Emptied fields are sent as null, not dropped: the API reads a missing
    // key as "leave it alone", so dropping them would make a cleared phone
    // number come back on the next fetch.
    const payload = Object.fromEntries(
      keys.map((key) => [key, form[key].trim() || null]),
    ) as Record<string, string | null>

    const record = await persist(payload).catch(() => undefined)
    if (record) setSaved(form)
    return record
  }

  const isDirty = keys.some((key) => form[key] !== saved[key])

  return { form, set, save, submitAttempted, isDirty }
}

export function SupplierFormFields({
  form,
  set,
  submitAttempted,
  part,
}: Pick<ReturnType<typeof useSupplierForm>, 'form' | 'set' | 'submitAttempted'> & {
  /** One half only; omitted, every field shows. */
  part?: SupplierFormPart
}) {
  const showDetails = part !== 'address'
  const showAddress = part !== 'details'
  const { t } = useTranslation()
  const { states } = useCountryStates(form.country_code)
  return (
    <FieldGroup>
      {showDetails && (
        <>
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
        </>
      )}
      {showAddress && (
        <>
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
        </>
      )}
      {showDetails && (
        <Field>
          <FieldLabel htmlFor="supplier-notes">{t('admin.suppliers.fields.notes')}</FieldLabel>
          <Textarea
            id="supplier-notes"
            value={form.notes}
            onChange={(event) => set('notes', event.target.value)}
          />
        </Field>
      )}
    </FieldGroup>
  )
}
