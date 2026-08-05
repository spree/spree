import { ResourceMultiAutocomplete } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { customerAutocompleteProps } from '../../../hooks/use-customers'
import type { RuleEmbedRecord } from '../../../schemas/price-list'
import { EditorShell } from '../promotion-editors/editor-shell'
import type { PriceRuleEditorContext } from './types'

/**
 * Customer picker for `Spree::PriceRules::UserRule`. The preference key
 * is still `user_ids` on the wire (backend stays unchanged for backwards
 * compatibility); only the SPA surface reads "Customer".
 */
export function CustomerRuleEditor({ draft, onSave, onClose }: PriceRuleEditorContext) {
  const { t } = useTranslation()
  // Seed from `draft.customers` (the embed) — `preferences.user_ids` holds raw
  // integer IDs server-side while the embed carries the prefixed customer IDs
  // the picker round-trips.
  const [customerIds, setCustomerIds] = useState<string[]>(() =>
    (draft.customers ?? []).map((c) => c.id),
  )
  // RuleEmbedRecord, not Customer — the draft's embed fields are opaque to
  // keep the SDK object graph out of the form type (see RuleEmbedRecord).
  // The autocomplete still resolves full Customer records into this state.
  const [customers, setCustomers] = useState<RuleEmbedRecord[]>(draft.customers ?? [])

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, user_ids: customerIds },
      customers,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.fields.price_rule.customers.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            {...customerAutocompleteProps('price-rule-customers')}
            value={customerIds}
            onChange={setCustomerIds}
            onResolvedOptionsChange={setCustomers}
          />
          <p className="text-xs text-muted-foreground">
            {t('admin.fields.price_rule.customers.help')}
          </p>
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
