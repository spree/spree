import type { CustomerGroup } from '@spree/admin-sdk'
import { useState } from 'react'
import { ResourceMultiAutocomplete } from '@/components/spree/resource-multi-autocomplete'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { customerGroupAutocompleteProps } from '@/hooks/use-customer-groups'
import { EditorShell } from './editor-shell'
import type { PromotionRuleEditorContext } from './types'

export function CustomerGroupRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
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
          <FieldLabel>Customer groups</FieldLabel>
          <ResourceMultiAutocomplete
            {...customerGroupAutocompleteProps('promotion-rule-customer-groups')}
            value={groupIds}
            onChange={setGroupIds}
            onResolvedOptionsChange={setCustomerGroups}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
