import type { Collection } from '@spree/admin-sdk'
import { adminClient, ResourceMultiAutocomplete, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { EditorShell } from './editor-shell'
import { MatchPolicyPicker } from './match-policy-picker'
import type { PromotionRuleEditorContext } from './types'

type MatchPolicy = 'any' | 'all'
const MATCH_POLICY_VALUES: readonly MatchPolicy[] = ['any', 'all']

/**
 * Collections an order's products must belong to. Membership is the
 * collections' own (rule-matched and hand-picked alike); item-level actions
 * discount only their members.
 */
export function CollectionRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const matchPolicies = useMemo(
    () =>
      MATCH_POLICY_VALUES.map((value) => ({
        value,
        label: t(`admin.promotions.rules.collection.match_policy.${value}.label`),
        description: t(`admin.promotions.rules.collection.match_policy.${value}.description`),
      })),
    [t],
  )

  const initialMatchPolicy = ((draft.preferences?.match_policy as MatchPolicy) ??
    'any') as MatchPolicy
  const [matchPolicy, setMatchPolicy] = useState<MatchPolicy>(
    MATCH_POLICY_VALUES.includes(initialMatchPolicy) ? initialMatchPolicy : 'any',
  )
  const [collectionIds, setCollectionIds] = useState<string[]>(draft.collection_ids ?? [])
  const [collections, setCollections] = useState<Collection[]>(draft.collections ?? [])

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, match_policy: matchPolicy },
      collection_ids: collectionIds,
      collections,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <MatchPolicyPicker policies={matchPolicies} value={matchPolicy} onChange={setMatchPolicy} />

      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.promotions.rules.collection.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            queryKey="promotion-rule-collections"
            value={collectionIds}
            onChange={setCollectionIds}
            onResolvedOptionsChange={setCollections}
            search={(q) => adminClient.collections.list({ search: q, limit: 20, sort: 'name' })}
            hydrate={(ids) => adminClient.collections.list({ id_in: ids, limit: ids.length })}
            getOptionLabel={(c) => c.name ?? c.id}
            placeholder={t('admin.promotions.rules.collection.search_placeholder')}
            emptyText={t('admin.promotions.rules.collection.empty')}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
