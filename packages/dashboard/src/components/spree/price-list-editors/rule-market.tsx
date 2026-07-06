import type { Market } from '@spree/admin-sdk'
import { MarketMultiCombobox } from '@spree/dashboard-core'
import { Field, FieldGroup, FieldLabel } from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useAllMarkets } from '../../../hooks/use-markets'
import { EditorShell } from '../promotion-editors/editor-shell'
import type { PriceRuleEditorContext } from './types'

/**
 * Multi-select market picker for the Market price rule. Seeds from
 * `draft.markets` (the serializer embed) because `preferences.market_ids`
 * holds raw integer IDs server-side while the embed exposes the prefixed
 * `mkt_…` form the picker round-trips.
 */
export function MarketRuleEditor({ draft, onSave, onClose }: PriceRuleEditorContext) {
  const { t } = useTranslation()
  const { markets } = useAllMarkets()

  const [marketIds, setMarketIds] = useState<string[]>(() => (draft.markets ?? []).map((m) => m.id))

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
          <FieldLabel>{t('admin.fields.price_rule.markets.label')}</FieldLabel>
          <MarketMultiCombobox markets={markets} value={marketIds} onValueChange={setMarketIds} />
          <p className="text-xs text-muted-foreground">
            {t('admin.fields.price_rule.markets.help')}
          </p>
        </Field>
      </FieldGroup>
    </EditorShell>
  )
}
