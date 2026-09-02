import type { OptionValue } from '@spree/admin-sdk'
import { ResourceMultiAutocomplete, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import {
  filterOptionValues,
  optionValueLabel,
  useOptionTypes,
} from '../../../hooks/use-option-types'
import { EditorShell } from './editor-shell'
import type { PromotionRuleEditorContext } from './types'

export function OptionValueRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const { data: optionTypesData } = useOptionTypes()
  const allOptionValues = useMemo(
    () => optionTypesData?.data.flatMap((optionType) => optionType.option_values ?? []) ?? [],
    [optionTypesData],
  )

  const [optionValueIds, setOptionValueIds] = useState<string[]>(() =>
    (draft.option_values ?? []).map((optionValue) => optionValue.id),
  )
  const [optionValues, setOptionValues] = useState<OptionValue[]>(draft.option_values ?? [])

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, eligible_values: optionValueIds },
      option_values: optionValues,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.promotions.rules.option_value.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            queryKey="promotion-rule-option-values"
            initialItems={allOptionValues}
            value={optionValueIds}
            onChange={setOptionValueIds}
            onResolvedOptionsChange={setOptionValues}
            search={(query) =>
              Promise.resolve({ data: filterOptionValues(allOptionValues, query) })
            }
            hydrate={(ids) =>
              Promise.resolve({
                data: allOptionValues.filter((optionValue) => ids.includes(optionValue.id)),
              })
            }
            getOptionLabel={optionValueLabel}
            placeholder={t('admin.promotions.rules.option_value.search_placeholder')}
            emptyText={t('admin.promotions.rules.option_value.empty')}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
