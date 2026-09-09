import { PlusIcon, XIcon } from 'lucide-react'
import { Button } from '../ui/button'
import { Input } from '../ui/input'
import { InputGroup, InputGroupAddon, InputGroupInput } from '../ui/input-group'

/**
 * One rung of a quantity ladder: from `minQuantity` units up, the value is
 * `value`. What the value means is the caller's business — a unit price on a
 * price row, a percentage on a list's adjustment.
 */
export interface QuantityTierRow {
  /** Stable key for React. The caller owns it; a client-side id is fine. */
  id: string
  /** The quantity this rung applies from, as typed. */
  minQuantity: string
  /** The rung's figure, as typed. */
  value: string
  /**
   * Locked rungs render their quantity read-only. Used for the bottom rung of
   * a price ladder, which is the list's ordinary price and always quantity 1.
   */
  locked?: boolean
}

export interface QuantityTierEditorLabels {
  /** Column header over the quantity inputs. */
  quantity: string
  /** Column header over the value inputs. */
  value: string
  /** The "add a rung" button. */
  add: string
  /** Accessible name for a rung's remove button. `{quantity}` is substituted. */
  remove: string
  /** Shown in place of the rows when the ladder is empty. */
  empty?: string
  /** Shown under the rows — a validation message, or a hint. */
  hint?: string
}

export interface QuantityTierEditorProps {
  rows: QuantityTierRow[]
  labels: QuantityTierEditorLabels
  onChange: (id: string, field: 'minQuantity' | 'value', next: string) => void
  onAdd: () => void
  onRemove: (id: string) => void
  /** Prefix or suffix rendered inside the value input — a currency symbol, a `%`. */
  valueAddon?: string
  /** Which side the addon sits on. Defaults to a leading addon. */
  valueAddonAlign?: 'inline-start' | 'inline-end'
  /** Hides "add" once the ladder is full, so the cap is visible rather than a surprise. */
  canAdd?: boolean
  disabled?: boolean
  /** Rendered in destructive styling under the rows. */
  error?: string
}

/**
 * The `[Min qty | value]` ladder both halves of volume pricing are edited
 * through: fixed breaks on a variant's price rows, and quantity bands on a
 * price list's percentage (docs/plans/6.0-volume-pricing.md).
 *
 * Headless — it holds no state, fetches nothing and knows no translations.
 * The caller owns the rows and every string.
 */
export function QuantityTierEditor({
  rows,
  labels,
  onChange,
  onAdd,
  onRemove,
  valueAddon,
  valueAddonAlign = 'inline-start',
  canAdd = true,
  disabled,
  error,
}: QuantityTierEditorProps) {
  return (
    <div className="flex flex-col gap-2">
      {rows.length === 0 ? (
        labels.empty ? (
          <p className="text-xs text-muted-foreground">{labels.empty}</p>
        ) : null
      ) : (
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <span className="w-24">{labels.quantity}</span>
            <span className="flex-1">{labels.value}</span>
            <span className="w-8" />
          </div>
          {rows.map((row) => (
            <div key={row.id} className="flex items-center gap-2">
              <Input
                type="number"
                step="1"
                min="1"
                className="w-24"
                value={row.minQuantity}
                readOnly={row.locked}
                disabled={disabled}
                aria-label={labels.quantity}
                onChange={(event) => onChange(row.id, 'minQuantity', event.target.value)}
              />
              <InputGroup className="flex-1">
                {valueAddon && valueAddonAlign === 'inline-start' && (
                  <InputGroupAddon>{valueAddon}</InputGroupAddon>
                )}
                <InputGroupInput
                  type="number"
                  step="0.01"
                  value={row.value}
                  disabled={disabled}
                  aria-label={labels.value}
                  onChange={(event) => onChange(row.id, 'value', event.target.value)}
                />
                {valueAddon && valueAddonAlign === 'inline-end' && (
                  <InputGroupAddon align="inline-end">{valueAddon}</InputGroupAddon>
                )}
              </InputGroup>
              {/* The bottom rung is the ordinary price, not a tier — removing
                  it would be removing the price itself. */}
              {row.locked ? (
                <span className="w-8" />
              ) : (
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="size-8 shrink-0"
                  disabled={disabled}
                  aria-label={labels.remove.replace('{quantity}', row.minQuantity)}
                  onClick={() => onRemove(row.id)}
                >
                  <XIcon className="size-4" />
                </Button>
              )}
            </div>
          ))}
        </div>
      )}

      {canAdd && (
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="self-start"
          disabled={disabled}
          onClick={onAdd}
        >
          <PlusIcon className="size-4" />
          {labels.add}
        </Button>
      )}

      {error ? (
        <p className="text-xs text-destructive">{error}</p>
      ) : labels.hint ? (
        <p className="text-xs text-muted-foreground">{labels.hint}</p>
      ) : null}
    </div>
  )
}
