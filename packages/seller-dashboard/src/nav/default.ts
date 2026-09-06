import { hasVisibleSettingsEntries, i18n, nav } from '@spree/dashboard-core'
import {
  ClipboardCheckIcon,
  HomeIcon,
  PackageIcon,
  SettingsIcon,
  StoreIcon,
  TagIcon,
  TagsIcon,
} from '@spree/dashboard-ui/icons'
import { OnboardingNavBadge } from '../components/onboarding-nav-badge'

// The panel's built-in sidebar. Registered into the same registry a plugin
// writes to, so a marketplace can remove, reorder or add beside these with
// `defineDashboardPlugin({ nav: ... })` instead of forking the chrome.
//
// Positions leave room on either side (100/200/…) exactly as the operator's
// dashboard does, so a plugin slots between built-ins without renumbering.
//
// Subjects are the seller-branch CanCanCan subjects the API's `/me`
// serializes; an entry a member cannot act on is hidden by the same
// permission filter the operator's sidebar uses.

nav.add({
  key: 'home',
  label: i18n.t('nav.home'),
  path: '/',
  icon: HomeIcon,
  position: 50,
  subject: 'seller_profile',
})

// High in the rail while a seller is still being admitted: until they are
// approved it is the only thing that matters. A marketplace that admits
// sellers some other way removes it like any other entry.
nav.add({
  key: 'onboarding',
  label: i18n.t('nav.onboarding'),
  path: '/onboarding',
  icon: ClipboardCheckIcon,
  position: 100,
  subject: 'seller_profile',
  badge: OnboardingNavBadge,
})

nav.add({
  key: 'products',
  label: i18n.t('nav.products'),
  path: '/products',
  icon: TagIcon,
  position: 110,
  subject: 'Spree::Product',
})

// Offers are the seller's rows on the marketplace's own products, which is a
// different resource from the products they own outright — different moves,
// different table — so it gets its own entry rather than a tab on Products
// (docs/plans/6.0-seller-master-catalog-listings.md).
nav.add({
  key: 'offers',
  label: i18n.t('nav.offers'),
  path: '/offers',
  icon: TagsIcon,
  position: 115,
  subject: 'Spree::Variant',
})

nav.add({
  key: 'orders',
  label: i18n.t('nav.orders'),
  path: '/orders',
  icon: PackageIcon,
  position: 120,
  subject: 'Spree::Order',
})

nav.add({
  key: 'profile',
  label: i18n.t('nav.profile'),
  path: '/profile',
  icon: StoreIcon,
  position: 150,
  subject: 'seller_profile',
})

// Settings is a launcher for the secondary rail, not a page: the entries
// inside it live in `nav/settings.ts`. Bottom section and gated on there
// being something to see, exactly as the operator's dashboard does it — a
// member with no settings authority never opens an empty shell.
nav.add({
  key: 'settings',
  label: i18n.t('nav.settings'),
  path: '/settings',
  icon: SettingsIcon,
  if: ({ permissions }) => hasVisibleSettingsEntries(permissions),
  section: 'bottom',
  position: 100,
})
