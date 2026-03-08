import {
  BarChart3Icon,
  HomeIcon,
  InboxIcon,
  type LucideIcon,
  PackageIcon,
  SettingsIcon,
  TagIcon,
  UsersIcon,
} from 'lucide-react'
import type { ComponentProps } from 'react'
import { NavMain } from '@/components/nav-main'
import { NavUser } from '@/components/nav-user'
import { StoreSwitcher } from '@/components/store-switcher'
import { Sidebar, SidebarContent, SidebarFooter, SidebarHeader } from '@/components/ui/sidebar'

export type NavItem = {
  title: string
  url: string
  icon: LucideIcon
  items?: { title: string; url: string }[]
}

const navigation: NavItem[] = [
  {
    title: 'Home',
    url: '/',
    icon: HomeIcon,
  },
  {
    title: 'Orders',
    url: '/orders',
    icon: InboxIcon,
    items: [{ title: 'Draft Orders', url: '/orders/drafts' }],
  },
  {
    title: 'Products',
    url: '/products',
    icon: PackageIcon,
    items: [
      { title: 'Price Lists', url: '/products/price-lists' },
      { title: 'Stock', url: '/products/stock' },
      { title: 'Taxonomies', url: '/products/taxonomies' },
      { title: 'Options', url: '/products/options' },
    ],
  },
  {
    title: 'Customers',
    url: '/customers',
    icon: UsersIcon,
  },
  {
    title: 'Promotions',
    url: '/promotions',
    icon: TagIcon,
    items: [{ title: 'Gift Cards', url: '/promotions/gift-cards' }],
  },
  {
    title: 'Reports',
    url: '/reports',
    icon: BarChart3Icon,
  },
]

const bottomNavigation: NavItem[] = [
  {
    title: 'Settings',
    url: '/settings',
    icon: SettingsIcon,
  },
]

export function AppSidebar(props: ComponentProps<typeof Sidebar>) {
  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <StoreSwitcher />
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navigation} bottomItems={bottomNavigation} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
    </Sidebar>
  )
}
