import { i18n, nav, Subject } from '@spree/dashboard-core'
import {
  BarChart3Icon,
  HomeIcon,
  InboxIcon,
  PackageIcon,
  SettingsIcon,
  TagIcon,
  UsersIcon,
} from 'lucide-react'

nav.add({
  key: 'home',
  label: i18n.t('admin.nav.home'),
  path: '/',
  icon: HomeIcon,
  position: 100,
})

nav.add({
  key: 'orders',
  label: i18n.t('admin.nav.orders'),
  path: '/orders',
  icon: InboxIcon,
  subject: Subject.Order,
  position: 200,
  children: [
    {
      key: 'orders.drafts',
      label: i18n.t('admin.nav.draft_orders'),
      path: '/orders/drafts',
      subject: Subject.Order,
      position: 100,
    },
  ],
})

nav.add({
  key: 'products',
  label: i18n.t('admin.nav.products'),
  path: '/products',
  icon: PackageIcon,
  subject: Subject.Product,
  position: 300,
  children: [
    {
      key: 'products.price-lists',
      label: i18n.t('admin.nav.price_lists'),
      path: '/products/price-lists',
      subject: Subject.PriceList,
      position: 100,
    },
    {
      key: 'products.categories',
      label: i18n.t('admin.nav.categories'),
      path: '/products/categories',
      subject: Subject.Category,
      position: 300,
    },
    {
      key: 'products.options',
      label: i18n.t('admin.nav.options'),
      path: '/products/options',
      subject: Subject.OptionType,
      position: 400,
    },
    {
      key: 'products.transfers',
      label: i18n.t('admin.nav.transfers'),
      path: '/products/transfers',
      subject: Subject.StockTransfer,
      position: 500,
    },
  ],
})

nav.add({
  key: 'customers',
  label: i18n.t('admin.nav.customers'),
  path: '/customers',
  icon: UsersIcon,
  subject: Subject.Customer,
  position: 400,
  children: [
    {
      key: 'customers.groups',
      label: i18n.t('admin.nav.customer_groups'),
      path: '/customers/groups',
      subject: Subject.CustomerGroup,
      position: 100,
    },
  ],
})

nav.add({
  key: 'promotions',
  label: i18n.t('admin.nav.promotions'),
  path: '/promotions',
  icon: TagIcon,
  subject: Subject.Promotion,
  position: 500,
  children: [
    {
      key: 'promotions.gift-cards',
      label: i18n.t('admin.nav.gift_cards'),
      path: '/promotions/gift-cards',
      subject: Subject.GiftCard,
      position: 100,
    },
  ],
})

nav.add({
  key: 'reports',
  label: i18n.t('admin.nav.reports'),
  path: '/reports',
  icon: BarChart3Icon,
  position: 600,
})

nav.add({
  key: 'settings',
  label: i18n.t('admin.nav.settings'),
  path: '/settings',
  icon: SettingsIcon,
  subject: Subject.Store,
  section: 'bottom',
  position: 100,
  children: [
    {
      key: 'settings.shipping-methods',
      label: i18n.t('admin.nav.shipping_methods'),
      path: '/settings/shipping-methods',
      subject: Subject.ShippingMethod,
      position: 100,
    },
    {
      key: 'settings.tax-rates',
      label: i18n.t('admin.nav.tax_rates'),
      path: '/settings/tax-rates',
      subject: Subject.TaxRate,
      position: 200,
    },
    {
      key: 'settings.zones',
      label: i18n.t('admin.nav.zones'),
      path: '/settings/zones',
      subject: Subject.Zone,
      position: 300,
    },
  ],
})
