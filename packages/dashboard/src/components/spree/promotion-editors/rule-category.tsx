import type { Category } from '@spree/admin-sdk'
import { adminClient, ResourceMultiAutocomplete, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { EditorShell } from './editor-shell'
import { MatchPolicyPicker } from './match-policy-picker'
import type { PromotionRuleEditorContext } from './types'

type MatchPolicy = 'any' | 'all'
const MATCH_POLICY_VALUES: readonly MatchPolicy[] = ['any', 'all']

/**
 * Surfaced as "Category(ies)" per the 6.0 Taxon→Category rename.
 * Backed by `Spree::Promotion::Rules::Taxon` until the table rename
 * ships; descendant categories match implicitly server-side.
 */
export function CategoryRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const matchPolicies = useMemo(
    () =>
      MATCH_POLICY_VALUES.map((value) => ({
        value,
        label: t(`admin.promotions.rules.category.match_policy.${value}.label`),
        description: t(`admin.promotions.rules.category.match_policy.${value}.description`),
      })),
    [t],
  )

  const initialMatchPolicy = ((draft.preferences?.match_policy as MatchPolicy) ??
    'any') as MatchPolicy
  const [matchPolicy, setMatchPolicy] = useState<MatchPolicy>(
    MATCH_POLICY_VALUES.includes(initialMatchPolicy) ? initialMatchPolicy : 'any',
  )
  const [categoryIds, setCategoryIds] = useState<string[]>(draft.category_ids ?? [])
  const [categories, setCategories] = useState<Category[]>(draft.categories ?? [])

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, match_policy: matchPolicy },
      category_ids: categoryIds,
      categories,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <MatchPolicyPicker policies={matchPolicies} value={matchPolicy} onChange={setMatchPolicy} />

      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.promotions.rules.category.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            queryKey="promotion-rule-categories"
            value={categoryIds}
            onChange={setCategoryIds}
            onResolvedOptionsChange={setCategories}
            search={(q) =>
              adminClient.categories.list({ name_cont: q, limit: 20, sort: 'pretty_name' })
            }
            hydrate={(ids) => adminClient.categories.list({ id_in: ids, limit: ids.length })}
            getOptionLabel={(c) => c.pretty_name ?? c.name ?? c.id}
            placeholder={t('admin.promotions.rules.category.search_placeholder')}
            emptyText={t('admin.promotions.rules.category.empty')}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
