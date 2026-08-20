import { CountryCombobox, StateCombobox, useCountryStates } from '@spree/dashboard-core'
import { Field, FieldError, FieldLabel, Input } from '@spree/dashboard-ui'
import {
  Controller,
  type FieldValues,
  type Path,
  type FieldError as RhfFieldError,
  type UseFormReturn,
} from 'react-hook-form'
import { useTranslation } from 'react-i18next'

/**
 * The address block every form that captures one shares — name, street, city,
 * postal code, country/state pickers and phone.
 *
 * Generic over the form values so a page carrying an address under any key can
 * use it; `prefix` names that key.
 *
 * **Reach for `AddressFormDialog` (dashboard-core) first** — it owns one
 * address end to end, with its own sheet, Zod validation and 422 mapping, and
 * is what orders, customers and sellers use. This fieldset is for the case it
 * cannot serve: a form editing *several* addresses at once, where the fields
 * have to live inside a form the page already owns (a company location edits
 * billing and shipping together behind one "same as billing" toggle).
 *
 * Stock locations deliberately use neither: they are not addresses but a model
 * with its own flat columns and vocabulary (`zipcode`, `state_text`), so
 * sharing would mean a field-name mapping layer between form and API.
 */
export function AddressFieldset<TValues extends FieldValues>({
  form,
  prefix,
  legend,
}: {
  form: UseFormReturn<TValues>
  /** The form key holding the address block, e.g. `billing_address`. */
  prefix: Path<TValues>
  legend?: string
}) {
  const { t } = useTranslation()
  // Paths are composed as strings and cast once here: RHF cannot infer that
  // `${prefix}.city` is a key of TValues, and spelling every field out as a
  // generic parameter would make every caller declare its address shape twice.
  const path = (field: string) => `${prefix}.${field}` as Path<TValues>
  const countryCode = form.watch(path('country_code')) as string | undefined
  const { states } = useCountryStates(countryCode)

  // Server-side validation errors land under the same nested path the fields
  // are registered at, so each one renders beside the input it belongs to
  // rather than as one banner the merchant has to map back themselves.
  const errorFor = (field: string): RhfFieldError | undefined => {
    const block = form.formState.errors[prefix] as Record<string, RhfFieldError> | undefined

    return block?.[field]
  }

  return (
    <fieldset className="flex flex-col gap-4 rounded-md border p-4">
      {legend && <legend className="px-1 font-medium text-sm">{legend}</legend>}

      <div className="grid gap-4 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor={`${prefix}-first-name`}>
            {t('admin.fields.first_name.label')}
          </FieldLabel>
          <Input id={`${prefix}-first-name`} {...form.register(path('first_name'))} />
          <FieldError errors={[errorFor('first_name')]} />
        </Field>
        <Field>
          <FieldLabel htmlFor={`${prefix}-last-name`}>
            {t('admin.fields.last_name.label')}
          </FieldLabel>
          <Input id={`${prefix}-last-name`} {...form.register(path('last_name'))} />
          <FieldError errors={[errorFor('last_name')]} />
        </Field>
      </div>

      <Field>
        <FieldLabel htmlFor={`${prefix}-address1`}>{t('admin.fields.address1.label')}</FieldLabel>
        <Input id={`${prefix}-address1`} {...form.register(path('address1'))} />
        <FieldError errors={[errorFor('address1')]} />
      </Field>

      <Field>
        <FieldLabel htmlFor={`${prefix}-address2`}>{t('admin.fields.address2.label')}</FieldLabel>
        <Input id={`${prefix}-address2`} {...form.register(path('address2'))} />
        <FieldError errors={[errorFor('address2')]} />
      </Field>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor={`${prefix}-city`}>{t('admin.fields.city.label')}</FieldLabel>
          <Input id={`${prefix}-city`} {...form.register(path('city'))} />
          <FieldError errors={[errorFor('city')]} />
        </Field>
        <Field>
          <FieldLabel htmlFor={`${prefix}-postal-code`}>
            {t('admin.fields.postal_code.label')}
          </FieldLabel>
          <Input id={`${prefix}-postal-code`} {...form.register(path('postal_code'))} />
          <FieldError errors={[errorFor('postal_code')]} />
        </Field>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Field>
          <FieldLabel htmlFor={`${prefix}-country`}>{t('admin.fields.country.label')}</FieldLabel>
          <Controller
            name={path('country_code')}
            control={form.control}
            render={({ field }) => (
              <CountryCombobox
                value={field.value}
                onValueChange={(iso) => {
                  field.onChange(iso)
                  form.setValue(path('state_code'), '' as never, { shouldDirty: true })
                }}
              />
            )}
          />
          <FieldError errors={[errorFor('country_code')]} />
        </Field>
        {/* A country Spree has no subdivision list for still needs somewhere
            to put a region, so the picker falls back to a plain field rather
            than vanishing — otherwise the address simply cannot be completed. */}
        {countryCode && states.length > 0 ? (
          <Field>
            <FieldLabel htmlFor={`${prefix}-state`}>{t('admin.fields.state.label')}</FieldLabel>
            <Controller
              name={path('state_code')}
              control={form.control}
              render={({ field }) => (
                <StateCombobox
                  countryCode={countryCode}
                  states={states}
                  value={field.value}
                  onValueChange={field.onChange}
                />
              )}
            />
            <FieldError errors={[errorFor('state_code')]} />
          </Field>
        ) : (
          <Field>
            <FieldLabel htmlFor={`${prefix}-state-name`}>
              {t('admin.fields.state_name.label')}
            </FieldLabel>
            <Input id={`${prefix}-state-name`} {...form.register(path('state_name'))} />
            <FieldError errors={[errorFor('state_name')]} />
          </Field>
        )}
      </div>

      <Field>
        <FieldLabel htmlFor={`${prefix}-phone`}>{t('admin.fields.phone.label')}</FieldLabel>
        <Input id={`${prefix}-phone`} {...form.register(path('phone'))} />
        <FieldError errors={[errorFor('phone')]} />
      </Field>
    </fieldset>
  )
}
