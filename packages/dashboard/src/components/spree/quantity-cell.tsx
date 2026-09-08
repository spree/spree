import { Input, TableCell, TableHead } from '@spree/dashboard-ui'

/**
 * A column of counted quantities, and its header.
 *
 * Both exist to solve one alignment problem. A number typed into an `<Input>`
 * cannot sit flush with the cell's right edge — the field's own padding, and
 * the spin buttons Chrome reserves room for, hold it inside — so a header
 * right-aligned to the cell hangs past the digits below it. The field drops the
 * spinners and the header takes the field's padding, which puts label, typed
 * value and read-only value on the same right edge.
 *
 * The digits stay `tabular-nums` so counts line up down the column.
 */
const FIELD_INSET = 'pr-2.5'

export function QuantityHead({ children }: { children: React.ReactNode }) {
  return (
    <TableHead className="text-right">
      <span className={FIELD_INSET}>{children}</span>
    </TableHead>
  )
}

export function QuantityCell({
  editable,
  value,
  min,
  max,
  label,
  onChange,
}: {
  editable: boolean
  value: number
  min?: number
  max?: number
  label: string
  onChange: (value: number) => void
}) {
  return (
    <TableCell className="text-right">
      {editable ? (
        <Input
          type="number"
          min={min}
          max={max}
          value={value}
          onChange={(event) => onChange(Number(event.target.value))}
          className="ml-auto w-20 text-right tabular-nums [appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
          aria-label={label}
        />
      ) : (
        <span className={`tabular-nums ${FIELD_INSET}`}>{value}</span>
      )}
    </TableCell>
  )
}
