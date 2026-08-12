import { Checkbox, RadioGroup, RadioGroupItem } from '@spree/dashboard-ui'

/**
 * "All locations" versus a chosen few — the shape every fulfillment-origin
 * setting takes (delivery profiles, origin groups, pickup counters, channels).
 *
 * All locations is the empty array, not every box ticked: naming today's
 * locations would silently exclude any warehouse added later, which is the
 * opposite of what the merchant asked for.
 */
export function StockLocationScopeField({
  idPrefix,
  scope,
  onScopeChange,
  locations,
  selectedIds,
  onSelectedIdsChange,
  allLabel,
  selectedLabel,
  emptyLabel,
}: {
  /** Namespaces the input ids so several of these can share a page. */
  idPrefix: string
  scope: 'all' | 'selected'
  onScopeChange: (scope: 'all' | 'selected') => void
  locations: Array<{ id: string; name: string }>
  selectedIds: string[]
  onSelectedIdsChange: (ids: string[]) => void
  allLabel: string
  selectedLabel: string
  /** Shown instead of the list when the store has no locations yet. */
  emptyLabel: string
}) {
  return (
    <>
      <RadioGroup value={scope} onValueChange={(next) => onScopeChange(next as 'all' | 'selected')}>
        <label htmlFor={`${idPrefix}-all`} className="flex items-center gap-2 text-sm">
          <RadioGroupItem id={`${idPrefix}-all`} value="all" />
          {allLabel}
        </label>
        <label htmlFor={`${idPrefix}-selected`} className="flex items-center gap-2 text-sm">
          <RadioGroupItem id={`${idPrefix}-selected`} value="selected" />
          {selectedLabel}
        </label>
      </RadioGroup>

      {scope === 'selected' &&
        (locations.length === 0 ? (
          <p className="text-muted-foreground text-sm">{emptyLabel}</p>
        ) : (
          <div className="flex flex-col gap-2">
            {locations.map((location) => (
              <label
                key={location.id}
                htmlFor={`${idPrefix}-location-${location.id}`}
                className="flex items-center gap-2 text-sm"
              >
                <Checkbox
                  id={`${idPrefix}-location-${location.id}`}
                  checked={selectedIds.includes(location.id)}
                  onCheckedChange={(next) =>
                    onSelectedIdsChange(
                      next
                        ? [...selectedIds, location.id]
                        : selectedIds.filter((id) => id !== location.id),
                    )
                  }
                />
                {location.name}
              </label>
            ))}
          </div>
        ))}
    </>
  )
}
