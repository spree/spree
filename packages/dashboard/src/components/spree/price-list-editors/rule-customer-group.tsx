import type { CustomerGroup } from '@spree/admin-sdk'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { EditorShell } from '@/components/spree/promotion-editors/editor-shell'
import { ResourceMultiAutocomplete } from '@/components/spree/resource-multi-autocomplete'
import { customerGroupAutocompleteProps } from '@/hooks/use-customer-groups'
import type { PriceRuleEditorContext } from './types'

export function CustomerGroupRuleEditor({ draft, onSave, onClose }: PriceRuleEditorContext) {
  const { t } = useTranslation()
  const [groupIds, setGroupIds] = useState<string[]>(
    () => (draft.preferences?.customer_group_ids ?? []) as string[],
  )
  // Display-only embed echoed back onto the draft so the row summary
  // can render group names instead of prefixed IDs. Stripped at payload
  // time (see priceListValuesToParams).
  const [customerGroups, setCustomerGroups] = useState<CustomerGroup[]>(draft.customer_groups ?? [])

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, customer_group_ids: groupIds },
      customer_groups: customerGroups,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.fields.price_rule.customer_groups.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            {...customerGroupAutocompleteProps('price-rule-customer-groups')}
            value={groupIds}
            onChange={setGroupIds}
            onResolvedOptionsChange={setCustomerGroups}
          />
          <p className="text-xs text-muted-foreground">
            {t('admin.fields.price_rule.customer_groups.help')}
          </p>
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
