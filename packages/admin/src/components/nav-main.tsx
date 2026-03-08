import { Link, useRouterState } from '@tanstack/react-router'
import type { NavItem } from '@/components/app-sidebar'
import { TablerIcon } from '@/components/tabler-icon'
import {
  SidebarGroup,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarMenuSub,
  SidebarMenuSubButton,
  SidebarMenuSubItem,
} from '@/components/ui/sidebar'

function NavIcon({ name, isActive }: { name: string; isActive?: boolean }) {
  return (
    <span
      className={
        'inline-flex shrink-0 items-center justify-center rounded-lg p-[0.2rem] mr-2 transition-colors duration-100 ' +
        (isActive
          ? 'bg-zinc-950 text-white'
          : 'text-gray-400 group-hover/menu-button:text-zinc-950')
      }
    >
      <TablerIcon name={name} className="size-[1.125rem]" />
    </span>
  )
}

export function NavMain({ items, bottomItems }: { items: NavItem[]; bottomItems?: NavItem[] }) {
  const routerState = useRouterState()
  const currentPath = routerState.location.pathname

  return (
    <>
      <SidebarGroup>
        <SidebarMenu>
          {items.map((item) => {
            const isExactActive = currentPath === item.url
            const isActive = isExactActive || (item.url !== '/' && currentPath.startsWith(item.url))
            const hasActiveChild = item.items?.some(
              (sub) => currentPath === sub.url || currentPath.startsWith(sub.url),
            )
            const showSubmenu = isActive || hasActiveChild

            return (
              <SidebarMenuItem key={item.title}>
                <SidebarMenuButton
                  tooltip={item.title}
                  asChild
                  isActive={isActive && !hasActiveChild}
                >
                  <Link to={item.url}>
                    <NavIcon name={item.icon} isActive={isActive && !hasActiveChild} />
                    <span>{item.title}</span>
                  </Link>
                </SidebarMenuButton>
                {item.items && showSubmenu && (
                  <SidebarMenuSub>
                    {item.items.map((subItem) => {
                      const subActive =
                        currentPath === subItem.url || currentPath.startsWith(subItem.url)
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
          })}
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
                      <NavIcon name={item.icon} isActive={isActive} />
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
