import { Link, type LinkProps, useLocation, useRouter } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { Slot } from '@/components/spree/slot'
import { cn } from '@/lib/utils'

export interface PageTab {
  /** Stable key used for React lists. */
  key: string
  /** Visible label. */
  label: ReactNode
  /** Link target — same shape as TanStack Router <Link>. */
  to: LinkProps['to']
  /** Path/search params for the target route. */
  params?: LinkProps['params']
  search?: LinkProps['search']
  /**
   * Match strategy. `"exact"` (default) matches only when the pathname is
   * identical; `"prefix"` matches when the current pathname starts with `to`.
   */
  match?: 'exact' | 'prefix'
}

interface PageTabsProps {
  tabs: PageTab[]
  /** Slot name for plugin-injected tabs. Default `'page.tabs'`. */
  slotName?: string
  /** Slot context. Receives `{ tabs }` so plugins can inspect built-ins. */
  slotContext?: Record<string, unknown>
  className?: string
}

/**
 * Sub-route–aware tab strip. Each tab is a TanStack Router `<Link>`; the
 * active tab is the one whose `to` matches the current pathname.
 *
 * Replaces `shared/_page_tabs.html.erb` and the various `_*_nav.html.erb`
 * partials. Plugins extend by registering into the `page.tabs` slot.
 */
export function PageTabs({ tabs, slotName = 'page.tabs', slotContext, className }: PageTabsProps) {
  const location = useLocation()
  const router = useRouter()

  return (
    <nav className={cn('flex items-center gap-1 border-b border-border', className)}>
      {tabs.map((tab) => {
        // Resolve to an absolute pathname so prefix-mode doesn't match every tab
        // when `to` is an object/relative form. Mirrors what <Link> itself does.
        const target =
          typeof tab.to === 'string'
            ? tab.to
            : router.buildLocation({ to: tab.to, params: tab.params, search: tab.search }).pathname
        const active =
          tab.match === 'prefix'
            ? location.pathname.startsWith(target)
            : location.pathname === target
        return (
          <Link
            key={tab.key}
            // <Link> generics need a literal route path; PageTab is a generic
            // declarative API where `to` is unknown at this site.
            to={tab.to as never}
            params={tab.params}
            search={tab.search}
            className={cn(
              'inline-flex items-center px-3 py-2 -mb-px text-sm font-medium border-b-2 transition-colors',
              active
                ? 'border-foreground text-foreground'
                : 'border-transparent text-muted-foreground hover:text-foreground hover:border-border',
            )}
          >
            {tab.label}
          </Link>
        )
      })}
      <Slot name={slotName} context={{ tabs, ...slotContext }} />
    </nav>
  )
}
