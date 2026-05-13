import { type KeyboardEvent, type ReactNode, useEffect, useId, useRef, useState } from 'react'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { cn } from '@/lib/utils'
import { modeFor, useDataGridContext } from './context'
import type { CellCoords } from './types'
import { useStableCellRegistration } from './use-stable-cell-registration'

interface BaseCellProps {
  coords: CellCoords
  ariaLabel: string
}

interface NumberCellProps extends BaseCellProps {
  value: number
  onChange: (next: number) => void
  /** Visual hint — e.g. low-stock items get a colored border. */
  intent?: 'default' | 'warning'
}

/** Editable numeric cell. In selection mode the underlying input is
 *  read-only (so arrow keys navigate the grid); in edit mode it accepts
 *  typing and arrow keys move the caret. */
export function NumberCell({
  coords,
  value,
  onChange,
  ariaLabel,
  intent = 'default',
}: NumberCellProps) {
  const ctx = useDataGridContext()
  const inputRef = useRef<HTMLInputElement | null>(null)
  const [draft, setDraft] = useState(value.toString())
  const isSelected = ctx.isSelected(coords)
  const mode = modeFor(ctx.editing, coords)
  const isEditing = mode === 'edit'
  const isFocused = ctx.anchor?.row === coords.row && ctx.anchor?.col === coords.col

  // Resync draft with external value when not editing this cell.
  useEffect(() => {
    if (!isEditing) setDraft(value.toString())
  }, [value, isEditing])

  // Auto-focus + select when entering edit mode.
  useEffect(() => {
    if (isEditing) {
      const el = inputRef.current
      if (el) {
        el.focus()
        el.select()
      }
    }
  }, [isEditing])

  useStableCellRegistration(coords, {
    focus: () => inputRef.current?.focus(),
    read: () => value.toString(),
    write: (next) => {
      const n = Number(next)
      if (!Number.isFinite(n)) return
      onChange(Math.trunc(n))
    },
    canWrite: (next) => next === '' || Number.isFinite(Number(next)),
  })

  function commit() {
    const n = Number(draft)
    if (Number.isFinite(n)) onChange(Math.trunc(n))
    else setDraft(value.toString())
  }

  function onKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (!isEditing) {
      // Selection mode: forward navigation keys to the grid by NOT preventing
      // default. Mark this cell as the anchor on plain mouse-click style focus.
      return
    }
    if (event.key === 'Enter') {
      event.preventDefault()
      commit()
      ctx.setEditing(null)
      // Move down to mirror Excel.
      const next = { row: coords.row + 1, col: coords.col }
      ctx.setAnchor(next)
      ctx.setExtent(next)
      ctx.cells.get(`${next.row}.${next.col}`)?.focus()
    } else if (event.key === 'Escape') {
      event.preventDefault()
      setDraft(value.toString())
      ctx.setEditing(null)
    } else if (event.key === 'Tab') {
      event.preventDefault()
      commit()
      ctx.setEditing(null)
      const dx = event.shiftKey ? -1 : 1
      const next = { row: coords.row, col: coords.col + dx }
      ctx.setAnchor(next)
      ctx.setExtent(next)
      ctx.cells.get(`${next.row}.${next.col}`)?.focus()
    }
  }

  return (
    <input
      ref={inputRef}
      type="text"
      inputMode="numeric"
      value={isEditing ? draft : value.toString()}
      readOnly={!isEditing}
      onChange={(e) => setDraft(e.target.value)}
      onFocus={() => {
        ctx.setAnchor(coords)
        ctx.setExtent(coords)
      }}
      onDoubleClick={() => ctx.setEditing(coords)}
      onKeyDown={onKeyDown}
      onBlur={() => {
        if (isEditing) {
          commit()
          ctx.setEditing(null)
        }
      }}
      aria-label={ariaLabel}
      className={cn(
        'block h-9 w-full cursor-cell border-0 bg-transparent px-3 text-right tabular-nums outline-none ring-inset transition-colors',
        isSelected && 'bg-blue-500/10',
        isFocused && !isEditing && 'ring-2 ring-blue-500',
        isEditing && 'cursor-text bg-card ring-2 ring-blue-500',
        intent === 'warning' && !isSelected && !isFocused && 'text-amber-700',
      )}
    />
  )
}

interface SwitchCellProps extends BaseCellProps {
  value: boolean
  onChange: (next: boolean) => void
}

/** Boolean cell. Space toggles; there's no separate edit mode because the
 *  switch is a single-action control. */
export function SwitchCell({ coords, value, onChange, ariaLabel }: SwitchCellProps) {
  const ctx = useDataGridContext()
  const wrapRef = useRef<HTMLDivElement | null>(null)
  const isSelected = ctx.isSelected(coords)
  const isFocused = ctx.anchor?.row === coords.row && ctx.anchor?.col === coords.col

  useStableCellRegistration(coords, {
    focus: () => wrapRef.current?.focus(),
    read: () => (value ? 'true' : 'false'),
    write: (next) => {
      const lower = next.toLowerCase().trim()
      if (lower === 'true' || lower === '1' || lower === 'yes') onChange(true)
      else if (lower === 'false' || lower === '0' || lower === 'no' || lower === '') onChange(false)
    },
    canWrite: (next) =>
      ['', 'true', 'false', '1', '0', 'yes', 'no'].includes(next.toLowerCase().trim()),
  })

  function onKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    if (event.key === ' ' || event.key === 'Enter') {
      event.preventDefault()
      onChange(!value)
    }
  }

  return (
    <div
      ref={wrapRef}
      tabIndex={0}
      role="switch"
      aria-checked={value}
      aria-label={ariaLabel}
      onFocus={() => {
        ctx.setAnchor(coords)
        ctx.setExtent(coords)
      }}
      onKeyDown={onKeyDown}
      className={cn(
        'flex h-9 w-full cursor-cell items-center px-3 outline-none ring-inset transition-colors',
        isSelected && 'bg-blue-500/10',
        isFocused && 'ring-2 ring-blue-500',
      )}
    >
      <Switch checked={value} onCheckedChange={onChange} aria-hidden tabIndex={-1} />
    </div>
  )
}

interface SelectCellProps<V extends string> extends BaseCellProps {
  value: V
  onChange: (next: V) => void
  options: ReadonlyArray<{ value: V; label: string }>
}

/** Cell for fixed-option pickers. Enter opens the Select; arrow keys inside
 *  the open Select navigate options (Base UI default). Esc closes. */
export function SelectCell<V extends string>({
  coords,
  value,
  onChange,
  options,
  ariaLabel,
}: SelectCellProps<V>) {
  const ctx = useDataGridContext()
  const triggerRef = useRef<HTMLButtonElement | null>(null)
  const isSelected = ctx.isSelected(coords)
  const isFocused = ctx.anchor?.row === coords.row && ctx.anchor?.col === coords.col
  const id = useId()

  useStableCellRegistration(coords, {
    focus: () => triggerRef.current?.focus(),
    read: () => value,
    write: (next) => {
      if (options.some((o) => o.value === next)) onChange(next as V)
    },
    canWrite: (next) => options.some((o) => o.value === next) || next === '',
  })

  return (
    <Select items={options} value={value} onValueChange={(v) => onChange(v as V)}>
      <SelectTrigger
        ref={triggerRef}
        id={id}
        aria-label={ariaLabel}
        onFocus={() => {
          ctx.setAnchor(coords)
          ctx.setExtent(coords)
        }}
        className={cn(
          // Strip the Select's standard chrome so the cell reads as a flat
          // grid slot. The cell's own ring/bg comes from below.
          'h-9 min-h-0 w-full cursor-cell rounded-none border-0 bg-transparent px-3 text-sm shadow-none ring-inset transition-colors focus:border-0 focus:shadow-none',
          isSelected && 'bg-blue-500/10',
          isFocused && 'ring-2 ring-blue-500',
        )}
      >
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {options.map((opt) => (
          <SelectItem key={opt.value} value={opt.value}>
            {opt.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

interface ReadOnlyCellProps {
  children: ReactNode
  className?: string
}

/** Plain non-editable cell — first column of a row (e.g. label / link).
 *  Not registered with the grid, so Tab/arrows skip it. */
export function ReadOnlyCell({ children, className }: ReadOnlyCellProps) {
  return <div className={cn('flex h-9 items-center px-3 text-sm', className)}>{children}</div>
}
