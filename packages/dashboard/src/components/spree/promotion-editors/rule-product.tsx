import type { Product } from '@spree/admin-sdk'
import { useMemo, useState } from 'react'
import { adminClient } from '@/client'
import { ResourceMultiAutocomplete } from '@/components/spree/resource-multi-autocomplete'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { useTranslation } from '@/lib/i18n'
import { EditorShell } from './editor-shell'
import { MatchPolicyPicker } from './match-policy-picker'
import type { PromotionRuleEditorContext } from './types'

type MatchPolicy = 'any' | 'all' | 'none'
const MATCH_POLICY_VALUES: readonly MatchPolicy[] = ['any', 'all', 'none']

export function ProductRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const matchPolicies = useMemo(
    () =>
      MATCH_POLICY_VALUES.map((value) => ({
        value,
        label: t(`admin.promotions.rules.product.match_policy.${value}.label`),
        description: t(`admin.promotions.rules.product.match_policy.${value}.description`),
      })),
    [t],
  )

  const initialMatchPolicy = ((draft.preferences?.match_policy as MatchPolicy) ??
    'any') as MatchPolicy
  const [matchPolicy, setMatchPolicy] = useState<MatchPolicy>(
    MATCH_POLICY_VALUES.includes(initialMatchPolicy) ? initialMatchPolicy : 'any',
  )
  const [productIds, setProductIds] = useState<string[]>(draft.product_ids ?? [])
  const [products, setProducts] = useState<Product[]>(draft.products ?? [])

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, match_policy: matchPolicy },
      product_ids: productIds,
      products,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <MatchPolicyPicker policies={matchPolicies} value={matchPolicy} onChange={setMatchPolicy} />

      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.promotions.rules.product.label')}</FieldLabel>
          <ResourceMultiAutocomplete
            queryKey="promotion-rule-products"
            value={productIds}
            onChange={setProductIds}
            onResolvedOptionsChange={setProducts}
            search={(q) => adminClient.products.list({ name_cont: q, limit: 10, sort: 'name' })}
            hydrate={(ids) => adminClient.products.list({ id_in: ids, limit: ids.length })}
            getOptionLabel={(p) => p.name ?? p.id}
            placeholder={t('admin.promotions.rules.product.search_placeholder')}
            emptyText={t('admin.promotions.rules.product.empty')}
          />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
