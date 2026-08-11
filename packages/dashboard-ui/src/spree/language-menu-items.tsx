import { ChevronsUpDownIcon } from 'lucide-react'

interface LanguageMenuItemsProps {
  /** Translated "Language" label for the row (passed by the app). */
  label: string
  /** Admin UI languages available to switch to ({ code, name } pairs). */
  locales: ReadonlyArray<{ code: string; name: string }>
  /** Currently active language code. */
  value: string
  onSelect: (code: string) => void
}

/**
 * Admin UI language picker rendered inside the user dropdown's Preferences
 * section, as a native `<select>`.
 *
 * Native rather than the design system's `Select`: a menu nested inside a menu
 * is awkward to drive with a pointer and stacks two portal layers, while the
 * platform control opens as its own popup outside the dropdown entirely — and
 * gives long locale lists native scrolling and type-ahead for free. The
 * `<select>` is transparent and overlaid on the styled pill, so the row still
 * matches the Theme row above it.
 *
 * Headless: the label, locale list, and change handler are passed in, so this
 * component imports no i18n/data runtime. Renders nothing when fewer than two
 * languages are installed: there's nothing to choose.
 */
export function LanguageMenuItems({ label, locales, value, onSelect }: LanguageMenuItemsProps) {
  if (locales.length < 2) return null

  const current = locales.find((l) => l.code === value)

  return (
    // Not a DropdownMenuItem: the row is a container for the select, and menu
    // items steal the pointer and close the menu on click.
    <div className="relative flex items-center justify-between gap-2 rounded-lg px-2 py-1.5">
      <span className="text-sm text-foreground">{label}</span>
      <span className="pointer-events-none inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-2 py-1 text-xs font-normal text-foreground">
        {current?.name ?? value}
        <ChevronsUpDownIcon className="size-3 text-muted-foreground" />
      </span>
      {/* Invisible but hit-testable, sized to the pill it covers. */}
      <select
        aria-label={label}
        value={value}
        onChange={(event) => onSelect(event.target.value)}
        className="absolute inset-y-0 end-2 w-32 cursor-pointer opacity-0"
      >
        {locales.map((locale) => (
          <option key={locale.code} value={locale.code}>
            {locale.name}
          </option>
        ))}
      </select>
    </div>
  )
}
