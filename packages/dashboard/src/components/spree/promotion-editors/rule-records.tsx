import type { Category, Collection } from '@spree/admin-sdk'
import { adminClient, ResourceMultiAutocomplete, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { collectionAutocompleteProps } from '../../../hooks/use-collections'
import { EditorShell } from './editor-shell'
import { MatchPolicyPicker } from './match-policy-picker'
import type { PromotionRuleEditorContext, PromotionRuleFormDraft } from './types'

type MatchPolicy = 'any' | 'all'
const MATCH_POLICY_VALUES: readonly MatchPolicy[] = ['any', 'all']

interface RecordRuleConfig<T> {
  /** Locale key under `admin.promotions.rules`. */
  kind: string
  idsKey: 'category_ids' | 'collection_ids'
  recordsKey: 'categories' | 'collections'
  queryKey: string
  search: (query: string) => Promise<{ data: T[] }>
  hydrate: (ids: string[]) => Promise<{ data: T[] }>
  getOptionLabel: (record: T) => string
}

/**
 * The editor for a rule that names a set of records an order's products must
 * belong to — categories or collections — with an any/all match policy.
 */
function RecordRuleEditor<T extends { id: string }>({
  draft,
  onSave,
  onClose,
  config: { kind, idsKey, recordsKey, queryKey, search, hydrate, getOptionLabel },
}: PromotionRuleEditorContext & { config: RecordRuleConfig<T> }) {
  const { t } = useTranslation()
  const matchPolicies = useMemo(
    () =>
      MATCH_POLICY_VALUES.map((value) => ({
        value,
        label: t(`admin.promotions.rules.${kind}.match_policy.${value}.label`),
        description: t(`admin.promotions.rules.${kind}.match_policy.${value}.description`),
      })),
    [t, kind],
  )

  const initialMatchPolicy = ((draft.preferences?.match_policy as MatchPolicy) ??
    'any') as MatchPolicy
  const [matchPolicy, setMatchPolicy] = useState<MatchPolicy>(
    MATCH_POLICY_VALUES.includes(initialMatchPolicy) ? initialMatchPolicy : 'any',
  )
  const [ids, setIds] = useState<string[]>(draft[idsKey] ?? [])
  const [records, setRecords] = useState<T[]>((draft[recordsKey] ?? []) as unknown as T[])

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, match_policy: matchPolicy },
      [idsKey]: ids,
      [recordsKey]: records,
    } as PromotionRuleFormDraft)
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <MatchPolicyPicker policies={matchPolicies} value={matchPolicy} onChange={setMatchPolicy} />

      <FieldGroup>
        <Field>
          <FieldLabel>{t(`admin.promotions.rules.${kind}.label`)}</FieldLabel>
          <ResourceMultiAutocomplete<T>
            queryKey={queryKey}
            value={ids}
            onChange={setIds}
            onResolvedOptionsChange={setRecords}
            search={search}
            hydrate={hydrate}
            getOptionLabel={getOptionLabel}
            placeholder={t(`admin.promotions.rules.${kind}.search_placeholder`)}
            emptyText={t(`admin.promotions.rules.${kind}.empty`)}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}

/**
 * Surfaced as "Category(ies)" per the 6.0 Taxon→Category rename.
 * Descendant categories match implicitly server-side.
 */
const CATEGORY_RULE: RecordRuleConfig<Category> = {
  kind: 'category',
  idsKey: 'category_ids',
  recordsKey: 'categories',
  queryKey: 'promotion-rule-categories',
  search: (q) => adminClient.categories.list({ name_cont: q, limit: 20, sort: 'pretty_name' }),
  hydrate: (ids) => adminClient.categories.list({ id_in: ids, limit: ids.length }),
  getOptionLabel: (category) => category.pretty_name ?? category.name ?? category.id,
}

export function CategoryRuleEditor(context: PromotionRuleEditorContext) {
  return <RecordRuleEditor {...context} config={CATEGORY_RULE} />
}

const collectionPicker = collectionAutocompleteProps('promotion-rule-collections')

/**
 * Collections an order's products must belong to. Membership is the
 * collections' own (rule-matched and hand-picked alike); item-level actions
 * discount only their members.
 */
const COLLECTION_RULE: RecordRuleConfig<Collection> = {
  kind: 'collection',
  idsKey: 'collection_ids',
  recordsKey: 'collections',
  queryKey: collectionPicker.queryKey,
  search: collectionPicker.search,
  hydrate: collectionPicker.hydrate,
  getOptionLabel: collectionPicker.getOptionLabel,
}

export function CollectionRuleEditor(context: PromotionRuleEditorContext) {
  return <RecordRuleEditor {...context} config={COLLECTION_RULE} />
}
