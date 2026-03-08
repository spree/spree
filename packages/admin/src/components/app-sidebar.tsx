import type { ComponentProps } from 'react'
import { NavMain } from '@/components/nav-main'
import { NavUser } from '@/components/nav-user'
import { StoreSwitcher } from '@/components/store-switcher'
import { Sidebar, SidebarContent, SidebarFooter, SidebarHeader } from '@/components/ui/sidebar'

export type NavItem = {
  title: string
  url: string
  icon: string
  items?: { title: string; url: string }[]
}

const navigation: NavItem[] = [
  {
    title: 'Home',
    url: '/',
    icon: 'home',
  },
  {
    title: 'Orders',
    url: '/orders',
    icon: 'inbox',
    items: [{ title: 'Draft Orders', url: '/orders/drafts' }],
  },
  {
    title: 'Products',
    url: '/products',
    icon: 'package',
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
    icon: 'users',
  },
  {
    title: 'Promotions',
    url: '/promotions',
    icon: 'discount',
    items: [{ title: 'Gift Cards', url: '/promotions/gift-cards' }],
  },
  {
    title: 'Reports',
    url: '/reports',
    icon: 'chart-bar',
  },
]

const bottomNavigation: NavItem[] = [
  {
    title: 'Settings',
    url: '/settings',
    icon: 'settings',
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
