import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  SidebarGroup,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarMenuSub,
  SidebarMenuSubButton,
  SidebarMenuSubItem,
  useSidebar,
} from '@spree/dashboard-ui'
import { Link, useRouterState } from '@tanstack/react-router'
import type { LucideIcon } from 'lucide-react'
import { type ComponentType, useCallback, useEffect, useRef, useState } from 'react'
import type { SubjectName } from '../lib/permissions'

export type NavItem = {
  title: string
  url: string
  icon: LucideIcon
  /** CanCanCan subject required to see this item. If omitted, item is always visible. */
  subject?: SubjectName
  /** Component rendered after the label (e.g. a count badge). May return null. */
  badge?: ComponentType
  items?: {
    title: string
    url: string
    subject?: SubjectName
    /** Component rendered after the label, same contract as the parent's. */
    badge?: ComponentType
  }[]
}

export function NavIcon({ icon: Icon, isActive }: { icon: NavItem['icon']; isActive?: boolean }) {
  return (
    <span
      className={
        'inline-flex shrink-0 items-center justify-center rounded-lg p-[0.2rem] transition-colors duration-100 ' +
        (isActive ? 'text-foreground' : 'group-hover/menu-button:text-foreground')
      }
    >
      <Icon size={16} strokeWidth={2} />
    </span>
  )
}

/** Grace period between leaving the trigger/menu and the menu closing. */
const HOVER_CLOSE_DELAY_MS = 150

/**
 * Which collapsed-nav menu is open, shared across the whole rail.
 *
 * One value rather than per-item state, so the menus are mutually exclusive by
 * construction: hovering a neighbour replaces the open key instantly instead of
 * leaving the previous menu on screen for the close delay, which read as two
 * panels flickering over each other.
 */
interface HoverMenuController {
  openKey: string | null
  /** Opens `key` immediately, replacing whatever was open. */
  open: (key: string) => void
  /** Schedules a close, but only if `key` is still the open one. */
  closeSoon: (key: string) => void
  /** Closes right away — for explicit dismissals (Escape, selecting an item). */
  closeNow: () => void
  /** Cancels a pending close (pointer came back). */
  cancelClose: () => void
}

function useHoverMenuController(): HoverMenuController {
  const [openKey, setOpenKey] = useState<string | null>(null)
  const closeTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const cancelClose = useCallback(() => {
    if (closeTimer.current) {
      clearTimeout(closeTimer.current)
      closeTimer.current = null
    }
  }, [])

  const open = useCallback(
    (key: string) => {
      cancelClose()
      setOpenKey(key)
    },
    [cancelClose],
  )

  const closeSoon = useCallback(
    (key: string) => {
      cancelClose()
      closeTimer.current = setTimeout(() => {
        // Guarded so a late timer from the menu the pointer just left can't
        // close the one it has since moved to.
        setOpenKey((current) => (current === key ? null : current))
      }, HOVER_CLOSE_DELAY_MS)
    },
    [cancelClose],
  )

  const closeNow = useCallback(() => {
    cancelClose()
    setOpenKey(null)
  }, [cancelClose])

  useEffect(
    () => () => {
      if (closeTimer.current) clearTimeout(closeTimer.current)
    },
    [],
  )

  return { openKey, open, closeSoon, closeNow, cancelClose }
}

function CollapsedDropdown({
  item,
  controller,
  children,
}: {
  item: NavItem
  controller: HoverMenuController
  children: React.ReactNode
}) {
  const key = item.title
  const open = controller.openKey === key
  const openNow = () => controller.open(key)
  const closeSoon = () => controller.closeSoon(key)

  return (
    <DropdownMenu
      open={open}
      // Base UI's own open/close signals (Escape, outside click, selecting an
      // item) are explicit dismissals, so they close immediately — the grace
      // period exists only for the pointer leaving on its way somewhere.
      onOpenChange={(next) => {
        if (next) controller.open(key)
        else controller.closeNow()
      }}
    >
      {/* `nativeButton={false}` because the trigger renders a `<div>` wrapping
          a `SidebarMenuButton` (whose inner element is a `<Link>` → `<a>`),
          not a `<button>`. The wrapper exists to attach `onMouseLeave` for
          the hover-out close, so we can't drop it; instead we tell Base UI
          we're rendering a non-button trigger and let it apply menu role +
          keyboard semantics. */}
      <DropdownMenuTrigger asChild nativeButton={false} onMouseEnter={openNow}>
        {/* biome-ignore lint/a11y/noStaticElementInteractions: hover trigger for collapsed nav */}
        <div onMouseLeave={closeSoon}>{children}</div>
      </DropdownMenuTrigger>
      {/* `sideOffset={0}` closes the dead zone the pointer used to cross: at
          4px the gap belonged to neither surface, so travelling to the menu
          read as leaving both. The visual separation comes from `ms-1`
          padding on the panel instead, which stays inside its hover area. */}
      <DropdownMenuContent
        side="right"
        align="start"
        sideOffset={0}
        className="ms-1"
        onMouseLeave={closeSoon}
        onMouseEnter={openNow}
      >
        {item.items!.map((subItem) => (
          <DropdownMenuItem key={subItem.title} asChild>
            <Link to={subItem.url} className="no-underline">
              {subItem.title}
            </Link>
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

function NavItemContent({
  item,
  currentPath,
  isCollapsed,
  hoverMenu,
}: {
  item: NavItem
  currentPath: string
  isCollapsed: boolean
  hoverMenu: HoverMenuController
}) {
  const isExactActive = currentPath === item.url || currentPath === `${item.url}/`
  // Only prefix-match for items with a sub-path after the storeId segment (e.g. /store_abc/orders)
  const hasSubPath = item.url.split('/').filter(Boolean).length > 1
  const isActive = isExactActive || (hasSubPath && currentPath.startsWith(item.url))
  const hasActiveChild = item.items?.some(
    (sub) => currentPath === sub.url || currentPath.startsWith(sub.url),
  )
  const showSubmenu = isActive || hasActiveChild
  const itemIsActive = isActive || !!hasActiveChild

  const button = (
    <SidebarMenuButton
      tooltip={!item.items || !isCollapsed ? item.title : undefined}
      asChild
      isActive={itemIsActive}
    >
      {/* `aria-label` because the visible label is hidden in collapsed icon
          mode, which would otherwise leave the link with no accessible name —
          an icon-only link is unusable to a screen reader. */}
      <Link to={item.url} aria-label={isCollapsed ? item.title : undefined}>
        <NavIcon icon={item.icon} isActive={itemIsActive} />
        {/* Explicitly hide in collapsed icon mode: a trailing badge span would
            otherwise steal the `span:last-child` position the base button style
            relies on to hide the label, leaving the title visible. */}
        <span className="group-data-[collapsible=icon]:hidden">{item.title}</span>
        {/* `shrink-0` so the badge keeps its shape while the sidebar width
            animates — a squeezed badge deforms before the label clips. */}
        {item.badge && (
          <span className="ml-auto shrink-0 group-data-[collapsible=icon]:hidden">
            <item.badge />
          </span>
        )}
      </Link>
    </SidebarMenuButton>
  )

  return (
    // Hovering an item with no submenu dismisses whatever menu is open: the
    // pointer has clearly moved on, and leaving a neighbour's panel hanging
    // over the rail reads as a stuck popup.
    <SidebarMenuItem onMouseEnter={isCollapsed && !item.items ? hoverMenu.closeNow : undefined}>
      {isCollapsed && item.items ? (
        <CollapsedDropdown item={item} controller={hoverMenu}>
          {button}
        </CollapsedDropdown>
      ) : (
        button
      )}
      {item.items && showSubmenu && (
        <SidebarMenuSub>
          {item.items.map((subItem) => {
            const subActive = currentPath === subItem.url || currentPath.startsWith(subItem.url)
            return (
              <SidebarMenuSubItem key={subItem.title}>
                <SidebarMenuSubButton asChild isActive={subActive}>
                  <Link to={subItem.url}>
                    <span>{subItem.title}</span>
                    {subItem.badge && (
                      <span className="ml-auto">
                        <subItem.badge />
                      </span>
                    )}
                  </Link>
                </SidebarMenuSubButton>
              </SidebarMenuSubItem>
            )
          })}
        </SidebarMenuSub>
      )}
    </SidebarMenuItem>
  )
}

export function NavMain({ items, bottomItems }: { items: NavItem[]; bottomItems?: NavItem[] }) {
  const routerState = useRouterState()
  const currentPath = routerState.location.pathname
  const { state } = useSidebar()
  const isCollapsed = state === 'collapsed'
  // One controller for the whole rail so only a single hover menu is ever open.
  const hoverMenu = useHoverMenuController()

  return (
    <>
      <SidebarGroup>
        <SidebarMenu>
          {items.map((item) => (
            <NavItemContent
              key={item.title}
              item={item}
              currentPath={currentPath}
              isCollapsed={isCollapsed}
              hoverMenu={hoverMenu}
            />
          ))}
        </SidebarMenu>
      </SidebarGroup>

      {bottomItems && bottomItems.length > 0 && (
        <SidebarGroup className="mt-auto mb-2">
          <SidebarMenu>
            {bottomItems.map((item) => {
              const isActive =
                currentPath === item.url || (item.url !== '/' && currentPath.startsWith(item.url))

              return (
                <SidebarMenuItem key={item.title}>
                  <SidebarMenuButton tooltip={item.title} asChild isActive={isActive}>
                    <Link to={item.url}>
                      <NavIcon icon={item.icon} isActive={isActive} />
                      <span>{item.title}</span>
                    </Link>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              )
            })}
          </SidebarMenu>
        </SidebarGroup>
      )}
    </>
  )
}
