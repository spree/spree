import type { Market } from '@spree/admin-sdk'
import { MarketMultiCombobox, useTranslation } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { useAllMarkets } from '../../../hooks/use-markets'
import { EditorShell } from './editor-shell'
import type { PromotionRuleEditorContext } from './types'

/**
 * Multi-select market picker for the promotion Market rule. Reads and writes
 * the prefixed ids in `preferences.market_ids`.
 */
export function MarketRuleEditor({ draft, onSave, onClose }: PromotionRuleEditorContext) {
  const { t } = useTranslation()
  const { markets } = useAllMarkets()

  const [marketIds, setMarketIds] = useState<string[]>(
    () => (draft.preferences?.market_ids ?? []) as string[],
  )

  const selectedMarkets = useMemo<Market[]>(
    () =>
      marketIds
        .map((id) => markets.find((m) => m.id === id))
        .filter((m): m is Market => Boolean(m)),
    [marketIds, markets],
  )

  function handleSave() {
    onSave({
      ...draft,
      preferences: { ...draft.preferences, market_ids: marketIds },
      markets: selectedMarkets,
    })
    onClose()
  }

  return (
    <EditorShell onSave={handleSave} onCancel={onClose} pending={false}>
      <FieldGroup>
        <Field>
          <FieldLabel>{t('admin.promotions.rules.market.label')}</FieldLabel>
          <MarketMultiCombobox markets={markets} value={marketIds} onValueChange={setMarketIds} />
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
