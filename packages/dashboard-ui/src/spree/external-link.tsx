import type * as React from 'react'
import { cn } from '../lib/utils'
import { ExternalLinkIcon } from './icons'

/**
 * A link that leaves the dashboard — documentation, a storefront, a carrier's
 * tracking page, a provider's console.
 *
 * The trailing arrow is the point: it tells the reader this one opens a new tab
 * before they click it, which a bare link cannot. Four hand-rolled versions of
 * this had grown across the two panels, each with its own colour, gap and icon
 * size, so a docs link looked like one thing next to a title and another inside
 * a card.
 *
 * `rel="noopener noreferrer"` is not optional on a `_blank` link: without
 * `noopener` the opened page can reach back through `window.opener` and
 * navigate this one.
 */
export function ExternalLink({
  className,
  children,
  ...props
}: React.ComponentProps<'a'> & { href: string }) {
  return (
    <a
      data-slot="external-link"
      target="_blank"
      rel="noopener noreferrer"
      className={cn(
        // `--link` rather than the accent: this is body-copy text, and the
        // accent fails 4.5:1 on both the card and the page.
        'inline-flex items-center gap-1 text-link transition-colors duration-100 ease-out hover:text-link-hover',
        // Sized relative to the text it sits in, so the arrow stays in
        // proportion whether the link is in a heading or a caption.
        '[&>svg]:size-[1em] [&>svg]:shrink-0',
        className,
      )}
      {...props}
    >
      {children}
      <ExternalLinkIcon aria-hidden />
    </a>
  )
}
