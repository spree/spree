import { SidebarInset, SidebarProvider } from '@spree/dashboard-ui'
import { useRouterState } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useEffect, useRef, useState } from 'react'
import { useAutoCollapseSidebar } from '../hooks/use-auto-collapse-sidebar'
import { StickyHeaderProvider } from '../providers/sticky-header-provider'
import { AppSidebar } from './app-sidebar'
import { MobileTopBar } from './mobile-top-bar'
import { SettingsNavSheet, SettingsSidebar } from './settings-sidebar'
import { SheetTopBar } from './sheet-top-bar'
import { SkipLink } from './skip-link'
import { MobileBreadcrumbBar } from './top-bar-breadcrumbs'

/**
 * The frame every panel renders inside: the nav rail, and the page as a sheet
 * beside it.
 *
 * There is no top bar. The rail carries what one used to — tenant switcher,
 * search, account — so the only chrome above a page is the page's own header,
 * and the content sits in an inset sheet rather than running to the window
 * edge.
 *
 * Both panels mount this rather than composing the same pieces twice: the
 * seller panel previously hand-rolled its own `<header>`, which had already
 * drifted from the dashboard's (a different border, a translucent fill the
 * dashboard had deliberately abandoned). One frame means one place to fix.
 */
export function AppShell({
  tenantId,
  sidebarHeader,
  inSettings,
  uiLocales,
  onEditProfile,
  children,
}: {
  /** Prefix for the nav links. Defaults to the route's `storeId`. */
  tenantId?: string
  /** Sidebar header — a store switcher by default, a seller switcher here. */
  sidebarHeader?: ReactNode
  /** True on a settings route, which brings its own secondary rail. */
  inSettings: boolean
  /** Admin UI languages for the account menu's language switcher. */
  uiLocales?: ReadonlyArray<{ code: string; name: string }>
  /** Opens the app's edit-profile dialog from the account menu. */
  onEditProfile?: () => void
  children: ReactNode
}) {
  // The settings area brings a full-width nav of its own, and two stacked
  // columns leave the content squeezed, so the primary rail folds to icons
  // while the user is in there.
  useAutoCollapseSidebar(inSettings)

  // Below `lg` the settings rail is hidden, so its sheet is the only way
  // between two settings pages. The trigger lives in the breadcrumb bar.
  const [settingsNavOpen, setSettingsNavOpen] = useState(false)

  // Put focus on the scroll container after each navigation, so Page Up/Down,
  // Home and End work on a freshly opened page without clicking into it first.
  // Those keys act on the focused element, and the shell's scroller is the only
  // thing that scrolls — left on <body>, they would have nothing to move.
  //
  // Skipped when focus is already inside the sheet: a route change that came
  // from typing in a filter must not pull the caret out of the field.
  const scrollerRef = useRef<HTMLDivElement | null>(null)
  const pathname = useRouterState({ select: (state) => state.location.pathname })
  useEffect(() => {
    // Read so the dependency is a real one: this effect exists to run on every
    // navigation, and `pathname` is what changes.
    if (!pathname) return
    const scroller = scrollerRef.current
    if (!scroller) return
    if (scroller.contains(document.activeElement)) return
    scroller.focus({ preventScroll: true })
  }, [pathname])

  return (
    <>
      {/* First in the tab order by construction — it has to precede the
          sidebar's thirty-odd links to be able to skip them. */}
      <SkipLink />
      <AppSidebar
        tenantId={tenantId}
        header={sidebarHeader}
        uiLocales={uiLocales}
        onEditProfile={onEditProfile}
      />
      {/* The sheet is exactly as tall as the viewport and scrolls internally,
          rather than growing with the page and letting the document scroll.
          Both of its rounded ends then stay on screen — with a document-length
          sheet the bottom two corners sit below the fold and the shape reads as
          a panel that has come unstuck. It also gives the page's sticky header
          a scroll container of its own to pin inside, so it can never ride up
          over the rail's switcher.

          `flex-row` so the secondary sidebar sits flush against the primary and
          spans the sheet's full height. */}
      <SidebarInset className="min-h-0 flex-row overflow-hidden">
        <SettingsSidebar open={inSettings} tenantId={tenantId} />
        {/* `tabIndex={-1}`: Page Up/Down, Home and End act on the focused
            element, and this is the element that scrolls. Without it focus
            stays on <body>, which has nothing to scroll now that the sheet
            owns the overflow — so those keys did nothing at all. `-1` keeps it
            out of the tab order while still letting a click or the skip link
            put focus here. `outline-none` because it is a scroll container
            rather than a control; the focus ring belongs to what is inside.

            `themed-scrollbar` because this is the last scroll container still
            on the browser default: the sheet owns the page's overflow, so its
            bar is the one a merchant sees most, and a chrome-grey native bar
            down the edge of the white sheet was the one piece of the frame
            that did not belong to the design. Not the quiet variant the
            settings nav uses — that one hides its thumb until hover, which
            suits chrome but not the surface being read, where the thumb is
            how you know where you are in a long list.

            `me-[5px]` insets the bar from the sheet's right edge. An arbitrary
            value rather than a scale step because the scale has no 5px rung —
            `1.5` is 6px — and this is measured against the sheet's edge by eye,
            so the exact figure is the point. A native
            scrollbar is painted by the browser at the scroll container's own
            border edge and no property can offset it, so the box itself has to
            end short of the sheet — margin does that, where padding would not:
            padding is inside the box, so the container would still end flush
            with the sheet and only the content would move, leaving the bar
            exactly where it was. Logical `me-` rather than `mr-` so the inset
            follows the bar to the left edge under RTL. */}
        <div
          ref={scrollerRef}
          tabIndex={-1}
          className="themed-scrollbar flex min-w-0 flex-1 flex-col overflow-y-auto me-[5px] outline-none"
        >
          <MobileTopBar uiLocales={uiLocales} onEditProfile={onEditProfile} />
          <SheetTopBar tenantId={tenantId} inSettings={inSettings} />
          <MobileBreadcrumbBar
            tenantId={tenantId}
            onOpenSettingsNav={() => setSettingsNavOpen(true)}
          />
          <SettingsNavSheet
            open={settingsNavOpen}
            onOpenChange={setSettingsNavOpen}
            tenantId={tenantId}
          />
          {/* Settings pages own their container so the secondary rail can sit
              flush; everything else gets the shell's. */}
          {inSettings ? (
            children
          ) : (
            <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:p-6">
              {children}
            </div>
          )}
        </div>
      </SidebarInset>
    </>
  )
}

/**
 * `AppShell` under the sidebar provider it needs.
 *
 * Split so the shell itself can call `useAutoCollapseSidebar`, which only
 * works inside the provider. `StickyHeaderProvider` rides along: it tracks
 * whether a page has a `PageHeader`, which decides heading levels below it.
 */
export function AppShellProvider({ children }: { children: ReactNode }) {
  return (
    <StickyHeaderProvider>
      <SidebarProvider>{children}</SidebarProvider>
    </StickyHeaderProvider>
  )
}
