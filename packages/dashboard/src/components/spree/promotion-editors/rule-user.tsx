import type { Customer } from '@spree/admin-sdk'
import { ResourceMultiAutocomplete, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { customerAutocompleteProps } from '../../../hooks/use-customers'
import { EditorShell } from './editor-shell'
import type { PromotionRuleEditorContext } from './types'

export function UserRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const [customerIds, setCustomerIds] = useState<string[]>(draft.customer_ids ?? [])
  const [customers, setCustomers] = useState<Customer[]>(draft.customers ?? [])

  function handleSave() {
    onSave({ ...draft, customer_ids: customerIds, customers })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.promotions.rules.customer.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            {...customerAutocompleteProps('promotion-rule-customers')}
            value={customerIds}
            onChange={setCustomerIds}
            onResolvedOptionsChange={setCustomers}
            placeholder={t('admin.promotions.rules.customer.search_placeholder')}
            emptyText={t('admin.promotions.rules.customer.empty')}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
