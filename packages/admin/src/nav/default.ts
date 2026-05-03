import {
  BarChart3Icon,
  HomeIcon,
  InboxIcon,
  PackageIcon,
  SettingsIcon,
  TagIcon,
  UsersIcon,
} from 'lucide-react'
import { nav } from '@/lib/nav-registry'
import { Subject } from '@/lib/permissions'

nav.add({
  key: 'home',
  label: 'Home',
  path: '/',
  icon: HomeIcon,
  position: 100,
})

nav.add({
  key: 'orders',
  label: 'Orders',
  path: '/orders',
  icon: InboxIcon,
  subject: Subject.Order,
  position: 200,
  children: [
    {
      key: 'orders.drafts',
      label: 'Draft Orders',
      path: '/orders/drafts',
      subject: Subject.Order,
      position: 100,
    },
  ],
})

nav.add({
  key: 'products',
  label: 'Products',
  path: '/products',
  icon: PackageIcon,
  subject: Subject.Product,
  position: 300,
  children: [
    {
      key: 'products.price-lists',
      label: 'Price Lists',
      path: '/products/price-lists',
      subject: Subject.Product,
      position: 100,
    },
    {
      key: 'products.stock',
      label: 'Stock',
      path: '/products/stock',
      subject: Subject.StockLocation,
      position: 200,
    },
    {
      key: 'products.categories',
      label: 'Categories',
      path: '/products/categories',
      subject: Subject.Taxon,
      position: 300,
    },
    {
      key: 'products.options',
      label: 'Options',
      path: '/products/options',
      subject: Subject.OptionType,
      position: 400,
    },
  ],
})

nav.add({
  key: 'customers',
  label: 'Customers',
  path: '/customers',
  icon: UsersIcon,
  subject: Subject.Customer,
  position: 400,
})

nav.add({
  key: 'promotions',
  label: 'Promotions',
  path: '/promotions',
  icon: TagIcon,
  subject: Subject.Promotion,
  position: 500,
  children: [
    {
      key: 'promotions.gift-cards',
      label: 'Gift Cards',
      path: '/promotions/gift-cards',
      subject: Subject.Promotion,
      position: 100,
    },
  ],
})

nav.add({
  key: 'reports',
  label: 'Reports',
  path: '/reports',
  icon: BarChart3Icon,
  position: 600,
})

nav.add({
  key: 'settings',
  label: 'Settings',
  path: '/settings',
  icon: SettingsIcon,
  subject: Subject.Store,
  section: 'bottom',
  position: 100,
})
