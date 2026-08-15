import type { Country } from '@spree/admin-sdk'
import { CountryMultiCombobox, useCountries, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { EditorShell } from './editor-shell'
import type { PromotionRuleEditorContext } from './types'

/**
 * Multi-select country picker for the promotion Country rule.
 *
 * Stores ISO codes — the `Country` resource has no numeric id, so its
 * primary key is `iso`. The rule's `country_codes` preference and the
 * display-only `countries` records are both derived from the selected
 * ISO set on save. The picker UI lives in the shared
 * `<CountryMultiCombobox>` so it stays consistent with the address-form
 * country pickers.
 */
export function CountryRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const { countries } = useCountries()

  const [countryCodes, setCountryCodes] = useState<string[]>(() =>
    ((draft.preferences?.country_codes ?? []) as string[]).map((s) => s.toUpperCase()),
  )

  // Display-only `countries` records for the rule summary — derived from the
  // cached list, stripped at payload time.
  const selectedCountries = useMemo<Country[]>(
    () =>
      countryCodes
        .map((iso) => countries.find((c) => c.iso === iso))
        .filter((c): c is Country => Boolean(c)),
    [countryCodes, countries],
  )

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, country_codes: countryCodes },
      countries: selectedCountries,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.promotions.rules.country.label')}</FieldLabel>
          <CountryMultiCombobox value={countryCodes} onValueChange={setCountryCodes} />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
