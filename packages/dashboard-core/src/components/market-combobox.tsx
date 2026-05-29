import type { Market } from '@spree/admin-sdk'
import {
  Combobox,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxValue,
  useComboboxAnchor,
} from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Searchable multi-select market picker. Value is an array of prefixed
 * market IDs; filters by name client-side against the caller-supplied
 * `markets` list (typically the long-cached `useAllMarkets()` set in
 * `@spree/dashboard`). Mirrors `<CountryMultiCombobox>` so the two
 * pickers feel identical to use.
 */
export function MarketMultiCombobox({
  markets,
  value,
  onValueChange,
  placeholder,
  emptyText,
  disabled = false,
}: {
  markets: Market[]
  /** Selected prefixed market IDs. */
  value: string[]
  onValueChange: (ids: string[]) => void
  placeholder?: string
  emptyText?: string
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const anchorRef = useComboboxAnchor()
  const [inputValue, setInputValue] = useState('')

  // Selected IDs not yet present in `markets` (list still loading) fall
  // back to a stub so chips don't vanish on first render.
  const selected = useMemo<Market[]>(
    () => value.map((id) => markets.find((m) => m.id === id) ?? ({ id, name: id } as Market)),
    [value, markets],
  )

  return (
    <Combobox
      multiple
      items={markets}
      value={selected}
      onValueChange={(next: Market[]) => {
        onValueChange(next.map((m) => m.id))
        setInputValue('')
      }}
      itemToStringLabel={(m: Market | null) => m?.name ?? ''}
      itemToStringValue={(m: Market | null) => m?.id ?? ''}
      isItemEqualToValue={(a: Market, b: Market) => a.id === b.id}
      disabled={disabled}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selectedMarkets: Market[]) =>
            selectedMarkets.map((m) => <ComboboxChip key={m.id}>{m.name}</ComboboxChip>)
          }
        </ComboboxValue>
        <ComboboxChipsInput
          placeholder={placeholder ?? t('admin.components.market_combobox.search_placeholder')}
          value={inputValue}
          onChange={(e) => setInputValue((e.target as HTMLInputElement).value)}
        />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxEmpty>{emptyText ?? t('admin.components.market_combobox.empty')}</ComboboxEmpty>
        <ComboboxList>
          {(market: Market) => (
            <ComboboxItem key={market.id} value={market}>
              {market.name}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
