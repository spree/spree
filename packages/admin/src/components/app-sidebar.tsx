import { NavMain } from '@/components/nav-main'
import { NavUser } from '@/components/nav-user'
import { StoreSwitcher } from '@/components/store-switcher'
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarRail,
} from '@/components/ui/sidebar'
import {
  LayoutDashboardIcon,
  PackageIcon,
  ShoppingCartIcon,
  UsersIcon,
  TagIcon,
  SettingsIcon,
} from 'lucide-react'
import type { ComponentProps } from 'react'

const navigation = [
  {
    title: 'Dashboard',
    url: '/',
    icon: <LayoutDashboardIcon />,
  },
  {
    title: 'Orders',
    url: '/orders',
    icon: <ShoppingCartIcon />,
  },
  {
    title: 'Products',
    url: '/products',
    icon: <PackageIcon />,
    isActive: true,
    items: [
      { title: 'All Products', url: '/products' },
    ],
  },
  {
    title: 'Categories',
    url: '/categories',
    icon: <TagIcon />,
  },
  {
    title: 'Customers',
    url: '/customers',
    icon: <UsersIcon />,
  },
  {
    title: 'Settings',
    url: '/settings',
    icon: <SettingsIcon />,
    items: [
      { title: 'General', url: '/settings' },
    ],
  },
]

export function AppSidebar(props: ComponentProps<typeof Sidebar>) {
  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <StoreSwitcher />
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navigation} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
      <SidebarRail />
    </Sidebar>
  )
}
