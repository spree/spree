import type { Store } from '@spree/admin-sdk'
// Entries use `labelKey` rather than a resolved `label` so the sidebar
// re-renders on language change — see app-sidebar.tsx for resolution.
import { hasVisibleSettingsEntries, nav, Subject } from '@spree/dashboard-core'
import {
  BarChart3Icon,
  HomeIcon,
  InboxIcon,
  MapIcon,
  PackageIcon,
  SettingsIcon,
  StoreIcon,
  TagIcon,
  UsersIcon,
} from 'lucide-react'
import { GettingStartedNavBadge } from '../components/spree/getting-started-nav-badge'
import {
  ClaimsNavBadge,
  ExchangesNavBadge,
  ReturnsNavBadge,
} from '../components/spree/post-sale-nav-badges'

nav.add({
  key: 'getting-started',
  labelKey: 'admin.nav.getting_started',
  path: '/getting-started',
  icon: MapIcon,
  position: 50,
  subject: Subject.Store,
  // Store setup is settings work — every staffer can READ the store (shell
  // data), so gate on the authority the tasks actually need.
  action: 'update',
  // Legacy-admin parity: the entry disappears once every setup task is done.
  if: ({ store }) => !!(store as Store | null)?.setup_tasks?.some((task) => !task.done),
  badge: GettingStartedNavBadge,
})

nav.add({
  key: 'home',
  labelKey: 'admin.nav.home',
  path: '/',
  icon: HomeIcon,
  position: 100,
})

nav.add({
  key: 'orders',
  labelKey: 'admin.nav.orders',
  path: '/orders',
  icon: InboxIcon,
  subject: Subject.Order,
  position: 200,
  children: [
    {
      key: 'orders.drafts',
      labelKey: 'admin.nav.draft_orders',
      path: '/orders/drafts',
      subject: Subject.Order,
      position: 100,
    },
    // Post-sale. These live under Orders because they are always about one,
    // and gating them on Order keeps a role that can see orders able to see
    // what came back from them.
    {
      key: 'returns',
      labelKey: 'admin.nav.returns',
      path: '/returns',
      subject: Subject.Order,
      position: 200,
      badge: ReturnsNavBadge,
    },
    {
      key: 'exchanges',
      labelKey: 'admin.nav.exchanges',
      path: '/exchanges',
      subject: Subject.Order,
      position: 300,
      badge: ExchangesNavBadge,
    },
    {
      key: 'claims',
      labelKey: 'admin.nav.claims',
      path: '/claims',
      subject: Subject.Order,
      position: 400,
      badge: ClaimsNavBadge,
    },
  ],
})

nav.add({
  key: 'products',
  labelKey: 'admin.nav.products',
  path: '/products',
  icon: PackageIcon,
  subject: Subject.Product,
  position: 300,
  children: [
    // Catalogs first: the catalog is the agreement a merchant sets up, and
    // a price list is one thing a catalog can own.
    {
      key: 'products.catalogs',
      labelKey: 'admin.nav.catalogs',
      path: '/products/catalogs',
      subject: Subject.Catalog,
      position: 100,
    },
    {
      key: 'products.price-lists',
      labelKey: 'admin.nav.price_lists',
      path: '/products/price-lists',
      subject: Subject.PriceList,
      position: 200,
    },
    {
      key: 'products.categories',
      labelKey: 'admin.nav.categories',
      path: '/products/categories',
      subject: Subject.Category,
      position: 300,
    },
    {
      key: 'products.collections',
      labelKey: 'admin.nav.collections',
      path: '/products/collections',
      subject: Subject.Collection,
      position: 350,
    },
    {
      key: 'products.options',
      labelKey: 'admin.nav.options',
      path: '/products/options',
      subject: Subject.OptionType,
      position: 400,
    },
    {
      key: 'products.media',
      labelKey: 'admin.nav.media',
      path: '/products/media',
      subject: Subject.Media,
      position: 450,
    },
    {
      key: 'products.transfers',
      labelKey: 'admin.nav.transfers',
      path: '/products/transfers',
      subject: Subject.StockTransfer,
      position: 500,
    },
  ],
})

nav.add({
  key: 'customers',
  labelKey: 'admin.nav.customers',
  path: '/customers',
  icon: UsersIcon,
  subject: Subject.Customer,
  position: 400,
  children: [
    {
      key: 'customers.groups',
      labelKey: 'admin.nav.customer_groups',
      path: '/customers/groups',
      subject: Subject.CustomerGroup,
      position: 100,
    },
    {
      key: 'customers.companies',
      labelKey: 'admin.nav.companies',
      path: '/companies',
      subject: Subject.Company,
      position: 200,
    },
  ],
})

// Only a marketplace has sellers, so the entry hides itself on a store whose
// staff hold no seller permission at all.
nav.add({
  key: 'sellers',
  labelKey: 'admin.nav.sellers',
  path: '/sellers',
  icon: StoreIcon,
  subject: Subject.Seller,
  position: 450,
})

nav.add({
  key: 'promotions',
  labelKey: 'admin.nav.promotions',
  path: '/promotions',
  icon: TagIcon,
  subject: Subject.Promotion,
  position: 500,
  children: [
    {
      key: 'promotions.gift-cards',
      labelKey: 'admin.nav.gift_cards',
      path: '/promotions/gift-cards',
      subject: Subject.GiftCard,
      position: 100,
    },
  ],
})

nav.add({
  key: 'reports',
  labelKey: 'admin.nav.reports',
  path: '/reports',
  icon: BarChart3Icon,
  position: 600,
})

nav.add({
  key: 'settings',
  labelKey: 'admin.nav.settings',
  path: '/settings',
  icon: SettingsIcon,
  // No `subject`: every staff member can read the store record (shell data),
  // so a Store check would show Settings to roles with nothing inside it.
  // Visible only when at least one settings page is reachable.
  if: ({ permissions }) => hasVisibleSettingsEntries(permissions),
  section: 'bottom',
  position: 100,
})
