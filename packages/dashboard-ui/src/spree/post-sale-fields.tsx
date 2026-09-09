import { useTranslation } from 'react-i18next'
import { Field, FieldLabel } from '../ui/field'
import { Input } from '../ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '../ui/select'

/** A unit on the order that a return, exchange or claim can name. */
export type PostSaleUnit = {
  id: string
  label: string
  quantity: number
}

/** How many of each unit a record covers; zero means "not included". */
export type PostSaleSelection = Record<string, number>

/**
 * Picks how many of each unit a post-sale record covers.
 *
 * Shared by the operator's order page and the seller's, so opening a return
 * looks the same on both sides of a marketplace.
 */
export function QuantityPicker({
  units,
  selection,
  onChange,
}: {
  units: PostSaleUnit[]
  selection: PostSaleSelection
  onChange: (selection: PostSaleSelection) => void
}) {
  return (
    <div className="flex flex-col gap-2">
      {units.map((unit) => (
        <div
          key={unit.id}
          className="flex items-center justify-between gap-4 rounded-lg border p-3"
        >
          <span className="min-w-0 truncate text-sm">{unit.label}</span>
          <Input
            type="number"
            min={0}
            max={unit.quantity}
            className="w-20"
            value={selection[unit.id] ?? 0}
            aria-label={unit.label}
            onChange={(event) =>
              onChange({
                ...selection,
                [unit.id]: Math.max(0, Math.min(Number(event.target.value), unit.quantity)),
              })
            }
          />
        </div>
      ))}
    </div>
  )
}

/** The units a record actually covers, as id/quantity pairs. */
export function selectedUnits(selection: PostSaleSelection): Array<[string, number]> {
  return Object.entries(selection).filter(([, quantity]) => quantity > 0)
}

/** One entry of a merchant's reason vocabulary. */
export type ReasonOption = {
  id: string
  name: string
}

/**
 * Reason dropdown, shared by every surface that records why something
 * happened. Optional by design — the API accepts a record without a reason,
 * and a merchant mid-return should not be blocked because nobody has curated
 * the list yet.
 *
 * With no `emptyOptionLabel` the field hides itself when the vocabulary is
 * empty, which suits a form that has other fields to fall back on. Passing one
 * keeps the field visible with an explicit "none" choice at the top, for a
 * surface where the reason is the point and its absence has to be sayable.
 *
 * The reasons come from the caller: each panel reads its own endpoint, and
 * which vocabulary a surface offers is not this component's business.
 */
export function ReasonField({
  id,
  reasons,
  value,
  onChange,
  label,
  emptyOptionLabel,
}: {
  /** Scopes the field id, since a page can show more than one of these. */
  id: string
  reasons: ReasonOption[]
  value: string
  onChange: (value: string) => void
  label?: string
  emptyOptionLabel?: string
}) {
  const { t } = useTranslation()

  if (reasons.length === 0 && emptyOptionLabel === undefined) return null

  // Base UI's <Select> needs `items` to resolve the trigger label; without it
  // the closed trigger renders the raw id (see CLAUDE.md).
  const options = [
    ...(emptyOptionLabel === undefined ? [] : [{ value: '', label: emptyOptionLabel }]),
    ...reasons.map((reason) => ({ value: reason.id, label: reason.name })),
  ]

  return (
    <Field>
      <FieldLabel htmlFor={`reason-${id}`}>
        {label ?? t('admin.pages.orders.detail.returns.reason')}
      </FieldLabel>
      <Select items={options} value={value} onValueChange={(next) => onChange(next ?? '')}>
        <SelectTrigger id={`reason-${id}`}>
          {/* An explicit empty choice IS the label for "none", so it must show
              rather than fall through to the placeholder Base UI renders for
              an unset value. */}
          <SelectValue placeholder={emptyOptionLabel ?? t('admin.common.select_placeholder')} />
        </SelectTrigger>
        <SelectContent>
          {options.map((option) => (
            <SelectItem key={option.value} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </Field>
  )
}
