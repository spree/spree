import { useEffect, useRef, useState } from 'react'
import { HexColorPicker } from 'react-colorful'
import { useTranslation } from 'react-i18next'
import { cn } from '../lib/utils'
import { Input } from '../ui/input'

/** Matches the server-side validation in `Spree::OptionValue#color_code`. */
const HEX_RE = /^#?[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/

function normalizeHex(input: string | null | undefined): string | null {
  if (!input) return null
  const trimmed = input.trim()
  if (!trimmed) return null
  const withHash = trimmed.startsWith('#') ? trimmed : `#${trimmed}`
  return HEX_RE.test(withHash) ? withHash.toUpperCase() : null
}

export interface ColorPickerProps {
  /** Hex value with `#` prefix (e.g. `#FF0000`). `null` / `undefined` / `''` for empty. */
  value: string | null | undefined
  /** Fires with a normalized `#RRGGBB` value, or `null` when cleared. */
  onChange: (value: string | null) => void
  /** Disables the trigger and locks the panel closed. */
  disabled?: boolean
  /** Forwarded to the text input for label association. */
  id?: string
  /** Forwarded to the text input. */
  'aria-invalid'?: boolean
  className?: string
  placeholder?: string
  /**
   * Hides the inline hex input — the swatch button alone becomes the trigger
   * and the hex input moves into the picker panel. Use in dense surfaces
   * (table cells, repeated row editors) where the inline input would crowd
   * the layout. Default `false`.
   */
  compact?: boolean
  /**
   * Which edge of the swatch the panel anchors to. `start` (default) grows
   * the panel rightward from the swatch's left edge; `end` grows it leftward
   * from the swatch's right edge — use when the swatch sits near the right
   * edge of its container (e.g. the rightmost cells in a table).
   */
  panelAlign?: 'start' | 'end'
}

/**
 * Hex color picker with a swatch trigger and a free-form text input.
 *
 * The picker panel is rendered **inline** (not via a portal) because Base UI's
 * `<Popover>` Portal mechanism interacts poorly with deeply-nested portal trees
 * (e.g. when the picker lives inside a `<Sheet>` inside a `<TableRow>` inside a
 * `useSortable` context — the Popup component silently fails to mount). The
 * inline approach uses an absolute-positioned panel with click-outside +
 * Escape-to-close handling.
 */
export function ColorPicker({
  value,
  onChange,
  disabled,
  id,
  'aria-invalid': ariaInvalid,
  className,
  placeholder = '#000000',
  compact = false,
  panelAlign = 'start',
}: ColorPickerProps) {
  const { t } = useTranslation()
  const normalizedValue = normalizeHex(value)
  const [open, setOpen] = useState(false)
  // Local text mirrors `value` but lets the user type freely (including
  // invalid intermediate states like `#FF`) without bouncing through onChange.
  const [text, setText] = useState(normalizedValue ?? '')
  const containerRef = useRef<HTMLDivElement | null>(null)

  // Resync when the form-level value changes (e.g. when the picker writes to
  // a different row, or when the form resets after a save).
  useEffect(() => {
    setText(normalizedValue ?? '')
  }, [normalizedValue])

  // `pointerdown` (not `click`) fires before the trigger's own click, matching
  // popover-library behavior so reopening doesn't double-toggle.
  useEffect(() => {
    if (!open) return
    function handle(event: PointerEvent) {
      const target = event.target as Node | null
      if (!target || !containerRef.current) return
      if (!containerRef.current.contains(target)) {
        setOpen(false)
      }
    }
    function handleKey(event: KeyboardEvent) {
      if (event.key === 'Escape') setOpen(false)
    }
    document.addEventListener('pointerdown', handle)
    document.addEventListener('keydown', handleKey)
    return () => {
      document.removeEventListener('pointerdown', handle)
      document.removeEventListener('keydown', handleKey)
    }
  }, [open])

  function commitText(raw: string) {
    const normalized = normalizeHex(raw)
    if (normalized) {
      onChange(normalized)
      setText(normalized)
    } else if (raw.trim() === '') {
      onChange(null)
      setText('')
    }
    // else: invalid input — keep the text, don't propagate
  }

  const hexInput = (
    <Input
      id={id}
      type="text"
      inputMode="text"
      autoComplete="off"
      spellCheck={false}
      value={text}
      placeholder={placeholder}
      disabled={disabled}
      aria-invalid={ariaInvalid}
      className="font-mono uppercase"
      onChange={(e) => setText(e.target.value)}
      onBlur={(e) => commitText(e.target.value)}
      onKeyDown={(e) => {
        if (e.key === 'Enter') {
          e.preventDefault()
          commitText(e.currentTarget.value)
        }
      }}
    />
  )

  return (
    <div ref={containerRef} className={cn('relative flex items-center gap-2', className)}>
      <button
        type="button"
        disabled={disabled}
        aria-label={
          normalizedValue
            ? t('admin.a11y.change_color', { value: normalizedValue })
            : t('admin.a11y.pick_color')
        }
        aria-haspopup="dialog"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        className={cn(
          'inline-flex size-10 shrink-0 cursor-pointer items-center justify-center rounded-md border border-border shadow-xs transition-shadow',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
          'disabled:cursor-not-allowed disabled:opacity-50',
          !normalizedValue && 'color-picker-empty-swatch',
        )}
        style={normalizedValue ? { backgroundColor: normalizedValue } : undefined}
      />
      {!compact && hexInput}
      {open && (
        <div
          role="dialog"
          aria-label={t('admin.a11y.pick_color')}
          className={cn(
            'absolute top-full z-50 mt-2 min-w-min rounded-lg border border-border bg-popover p-3 text-popover-foreground shadow-md',
            panelAlign === 'end' ? 'right-0' : 'left-0',
          )}
        >
          <HexColorPicker
            color={normalizedValue ?? '#000000'}
            onChange={(next) => {
              const normalized = normalizeHex(next)
              if (normalized) {
                setText(normalized)
                onChange(normalized)
              }
            }}
          />
          {compact && <div className="mt-3">{hexInput}</div>}
          <div className="mt-3 flex items-center justify-between gap-2">
            <span className="font-mono text-xs text-muted-foreground">
              {normalizedValue ?? t('admin.color_picker.no_color')}
            </span>
            {normalizedValue && (
              <button
                type="button"
                onClick={() => {
                  setText('')
                  onChange(null)
                }}
                className="text-xs text-muted-foreground underline-offset-2 hover:underline"
              >
                {t('admin.actions.clear')}
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
