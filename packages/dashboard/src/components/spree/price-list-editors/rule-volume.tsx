import { Field, FieldGroup, FieldLabel, Input } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { EditorShell } from '../promotion-editors/editor-shell'
import type { PriceRuleEditorContext } from './types'

/**
 * Min/max quantity editor for the Volume price rule. A custom editor is needed
 * for one reason the generic `<PreferencesForm>` can't handle: `defined_preferences`
 * serializes the two fields max-first (the preference registry isn't source-ordered),
 * and "maximum" reading before "minimum" is backwards for the reader. This editor
 * fixes the order (min first, max last) and — like the generic form's `isMaxKey`
 * handling — shows a blank maximum as "Unlimited".
 */
function toIntOrUndefined(value: string): number | undefined {
  const trimmed = value.trim()
  if (trimmed === '') return undefined
  const n = Number.parseInt(trimmed, 10)
  return Number.isFinite(n) ? n : undefined
}

export function VolumeRuleEditor({ draft, onSave, onClose }: PriceRuleEditorContext) {
  const { t } = useTranslation()

  const [minQuantity, setMinQuantity] = useState<string>(() =>
    draft.preferences.min_quantity != null ? String(draft.preferences.min_quantity) : '',
  )
  const [maxQuantity, setMaxQuantity] = useState<string>(() =>
    draft.preferences.max_quantity != null ? String(draft.preferences.max_quantity) : '',
  )

  function handleSave() {
    onSave({
      ...draft,
      preferences: {
        ...draft.preferences,
        min_quantity: toIntOrUndefined(minQuantity) ?? 1,
        // Blank → unlimited upper bound (null clears the server-side preference).
        max_quantity: toIntOrUndefined(maxQuantity) ?? null,
      },
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel htmlFor="volume-rule-min">{t('admin.preferences.min_quantity')}</FieldLabel>
          <Input
            id="volume-rule-min"
            type="number"
            min={1}
            value={minQuantity}
            onChange={(e) => setMinQuantity(e.target.value)}
          />
          <p className="text-xs text-muted-foreground">
            {t('admin.fields.price_rule.min_quantity.help')}
          </p>
        </Field>

        <Field>
          <FieldLabel htmlFor="volume-rule-max">{t('admin.preferences.max_quantity')}</FieldLabel>
          <Input
            id="volume-rule-max"
            type="number"
            min={1}
            value={maxQuantity}
            placeholder={t('admin.components.preferences_form.unlimited')}
            onChange={(e) => setMaxQuantity(e.target.value)}
          />
          <p className="text-xs text-muted-foreground">
            {t('admin.fields.price_rule.max_quantity.help')}
          </p>
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
