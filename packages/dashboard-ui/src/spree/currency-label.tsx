import i18n from 'i18next'
import type { ReactNode } from 'react'
import { cn } from '../lib/utils'
import { BanknoteIcon } from './icons'

/**
 * A currency's own symbol in the admin's language — `$`, `€`, `zł`, `R$` — or
 * null when it has none beyond its code (CHF, AED), so a caller never shows
 * the code twice.
 */
export function currencySymbol(code: string, locale: string = i18n.language): string | null {
  try {
    const symbol = new Intl.NumberFormat(locale, {
      style: 'currency',
      currency: code,
      currencyDisplay: 'narrowSymbol',
    })
      .formatToParts(0)
      .find((part) => part.type === 'currency')?.value
    return symbol && symbol !== code ? symbol : null
  } catch {
    return null
  }
}

/**
 * The currency's symbol in a small tile. Decorative: the code beside it is
 * what assistive technology reads. A currency with no symbol of its own
 * shows a banknote, so a column of tiles keeps one shape.
 */
export function CurrencySymbol({ code, className }: { code: string; className?: string }) {
  const symbol = currencySymbol(code)
  return (
    <span
      aria-hidden
      data-slot="currency-symbol"
      className={cn(
        'inline-flex h-5 min-w-5 shrink-0 items-center justify-center rounded-md bg-accent-strong-hover px-1 font-medium text-[11px] text-foreground leading-none',
        className,
      )}
    >
      {symbol ?? <BanknoteIcon className="size-3 text-muted-foreground" />}
    </span>
  )
}

/**
 * A currency as the dashboard shows it everywhere: its symbol tile, its code
 * and, when given, its name (`[$] USD US Dollar`).
 */
export function CurrencyLabel({
  code,
  name,
  className,
}: {
  code: string
  /** The localized name, shown muted after the code. Skipped when it is the code itself. */
  name?: ReactNode
  className?: string
}) {
  return (
    <span
      data-slot="currency-label"
      className={cn('inline-flex min-w-0 items-center gap-2', className)}
    >
      <CurrencySymbol code={code} />
      <span className="shrink-0">{code}</span>
      {name && name !== code && <span className="truncate text-muted-foreground">{name}</span>}
    </span>
  )
}
