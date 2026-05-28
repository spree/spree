import type { CustomerGroup } from '@spree/admin-sdk'
import { ResourceMultiAutocomplete, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { customerGroupAutocompleteProps } from '@/hooks/use-customer-groups'
import { EditorShell } from './editor-shell'
import type { PromotionRuleEditorContext } from './types'

export function CustomerGroupRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const [groupIds, setGroupIds] = useState<string[]>(
    () => (draft.preferences?.customer_group_ids ?? []) as string[],
  )
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
          <FieldLabel>{t('admin.promotions.rules.customer_group.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            {...customerGroupAutocompleteProps('promotion-rule-customer-groups')}
            value={groupIds}
            onChange={setGroupIds}
            onResolvedOptionsChange={setCustomerGroups}
            placeholder={t('admin.promotions.rules.customer_group.search_placeholder')}
            emptyText={t('admin.promotions.rules.customer_group.empty')}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
