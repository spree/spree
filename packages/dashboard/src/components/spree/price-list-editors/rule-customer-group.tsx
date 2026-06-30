import type { CustomerGroup } from '@spree/admin-sdk'
import { ResourceMultiAutocomplete } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { EditorShell } from '@/components/spree/promotion-editors/editor-shell'
import { customerGroupAutocompleteProps, useCustomerGroups } from '@/hooks/use-customer-groups'
import type { PriceRuleEditorContext } from './types'

export function CustomerGroupRuleEditor({ draft, onSave, onClose }: PriceRuleEditorContext) {
  const { t } = useTranslation()
  // Preload the full customer-group list so the picker surfaces options on
  // open without the merchant having to type — the list is small and cached.
  const { data: customerGroupsData } = useCustomerGroups()
  // Seed from `draft.customer_groups` (the embed) — `preferences.customer_group_ids`
  // holds raw integer IDs server-side while the embed carries the prefixed `cg_…`
  // IDs the picker round-trips.
  const [groupIds, setGroupIds] = useState<string[]>(() =>
    (draft.customer_groups ?? []).map((g) => g.id),
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
          <FieldLabel>{t('admin.fields.price_rule.customer_groups.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            {...customerGroupAutocompleteProps('price-rule-customer-groups')}
            initialItems={customerGroupsData?.data}
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
