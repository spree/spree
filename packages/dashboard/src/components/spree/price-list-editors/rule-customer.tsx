import type { Customer } from '@spree/admin-sdk'
import { ResourceMultiAutocomplete } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { EditorShell } from '@/components/spree/promotion-editors/editor-shell'
import { customerAutocompleteProps } from '@/hooks/use-customers'
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
  const [customers, setCustomers] = useState<Customer[]>(draft.customers ?? [])

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
