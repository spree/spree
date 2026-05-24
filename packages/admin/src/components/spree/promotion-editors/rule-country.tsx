import type { Country } from '@spree/admin-sdk'
import { useMemo, useState } from 'react'
import { CountryMultiCombobox } from '@/components/spree/country-combobox'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { useCountries } from '@/hooks/use-countries'
import { useTranslation } from '@/lib/i18n'
import { EditorShell } from './editor-shell'
import type { PromotionRuleEditorContext } from './types'

/**
 * Multi-select country picker for the promotion Country rule.
 *
 * Stores ISO codes — the `Country` resource has no numeric id, so its
 * primary key is `iso`. The rule's `country_isos` preference and the
 * display-only `countries` records are both derived from the selected
 * ISO set on save. The picker UI lives in the shared
 * `<CountryMultiCombobox>` so it stays consistent with the address-form
 * country pickers.
 */
export function CountryRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const { countries } = useCountries()

  const [countryIsos, setCountryIsos] = useState<string[]>(() =>
    ((draft.preferences?.country_isos ?? []) as string[]).map((s) => s.toUpperCase()),
  )

  // Display-only `countries` records for the rule summary — derived from the
  // cached list, stripped at payload time.
  const selectedCountries = useMemo<Country[]>(
    () =>
      countryIsos
        .map((iso) => countries.find((c) => c.iso === iso))
        .filter((c): c is Country => Boolean(c)),
    [countryIsos, countries],
  )

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, country_isos: countryIsos },
      countries: selectedCountries,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.promotions.rules.country.label')}</FieldLabel>
          <CountryMultiCombobox value={countryIsos} onValueChange={setCountryIsos} />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
