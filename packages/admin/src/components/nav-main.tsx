import { Link, useRouterState } from '@tanstack/react-router'
import { useState } from 'react'
import type { NavItem } from '@/components/app-sidebar'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import {
  SidebarGroup,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarMenuSub,
  SidebarMenuSubButton,
  SidebarMenuSubItem,
  useSidebar,
} from '@/components/ui/sidebar'

function NavIcon({ icon: Icon, isActive }: { icon: NavItem['icon']; isActive?: boolean }) {
  return (
    <span
      className={
        'inline-flex shrink-0 items-center justify-center rounded-lg p-[0.2rem] transition-colors duration-100 ' +
        (isActive
          ? 'bg-zinc-950 text-white'
          : 'text-gray-400 group-hover/menu-button:text-zinc-950')
      }
    >
      <Icon className="size-[1.125rem]" strokeWidth={2.25} />
    </span>
  )
}

function CollapsedDropdown({ item, children }: { item: NavItem; children: React.ReactNode }) {
  const [open, setOpen] = useState(false)

  return (
    <DropdownMenu open={open} onOpenChange={setOpen}>
      <DropdownMenuTrigger asChild onMouseEnter={() => setOpen(true)}>
        {/* biome-ignore lint/a11y/noStaticElementInteractions: hover trigger for collapsed nav */}
        <div onMouseLeave={() => setOpen(false)}>{children}</div>
      </DropdownMenuTrigger>
      <DropdownMenuContent
        side="right"
        align="start"
        sideOffset={4}
        onMouseLeave={() => setOpen(false)}
        onMouseEnter={() => setOpen(true)}
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
}: {
  item: NavItem
  currentPath: string
  isCollapsed: boolean
}) {
  const isExactActive = currentPath === item.url
  const isActive = isExactActive || (item.url !== '/' && currentPath.startsWith(item.url))
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
      <Link to={item.url}>
        <NavIcon icon={item.icon} isActive={itemIsActive} />
        <span>{item.title}</span>
      </Link>
    </SidebarMenuButton>
  )

  return (
    <SidebarMenuItem>
      {isCollapsed && item.items ? (
        <CollapsedDropdown item={item}>{button}</CollapsedDropdown>
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
            />
          ))}
        </SidebarMenu>
      </SidebarGroup>

      {bottomItems && bottomItems.length > 0 && (
        <SidebarGroup className="mt-auto">
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
