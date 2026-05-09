import { cn } from '@/lib/utils'

interface CountryFlagProps {
  /** ISO 3166-1 alpha-2 country code (case-insensitive). */
  iso: string
  /** Override the default `1.333em` × `1em` size. Pass any Tailwind size. */
  className?: string
}

/**
 * Renders a country flag via the `flag-icons` CSS sprite. The sprite resolves
 * `.fi.fi-{iso}` to a `background-image` URL pointing at the matching SVG —
 * the browser lazy-loads each flag only when it actually appears on screen.
 *
 * Decorative by design (`aria-hidden`); the surrounding label/text carries
 * the country name for screen readers.
 */
export function CountryFlag({ iso, className }: CountryFlagProps) {
  if (!iso) return null
  return (
    <span
      aria-hidden
      className={cn(
        'fi shrink-0 rounded-[2px] shadow-[0_0_0_0.5px_rgba(0,0,0,0.08)]',
        `fi-${iso.toLowerCase()}`,
        className,
      )}
    />
  )
}
