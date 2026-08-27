import { i18n, settingsNav } from '@spree/dashboard-core'
import { ScrollTextIcon, UsersRoundIcon, WarehouseIcon } from 'lucide-react'

// The panel's settings rail, registered into the same registry the operator's
// dashboard writes to — so a marketplace adds, removes or reorders entries
// with `defineDashboardPlugin` rather than forking the chrome.
//
// Deliberately short. Most of what an operator configures is the
// marketplace's, not a seller's; what belongs here is what a seller owns and
// only they can answer.

settingsNav.addGroup({
  key: 'fulfillment',
  labelKey: 'admin.settings_nav.groups.fulfillment',
  position: 200,
})

settingsNav.addGroup({
  key: 'legal',
  label: i18n.t('nav.legal'),
  position: 250,
})

settingsNav.addGroup({
  key: 'team',
  labelKey: 'admin.settings_nav.groups.team',
  position: 300,
})

settingsNav.add({
  key: 'settings.stock-locations',
  labelKey: 'admin.settings_nav.items.stock_locations',
  path: '/stock-locations',
  icon: WarehouseIcon,
  group: 'fulfillment',
  position: 100,
  // The seller-branch subject the API's `/me` serializes. A member without
  // stock permission never sees the entry.
  subject: 'Spree::StockLocation',
})

// Who runs this seller. Under settings rather than in the main rail, matching
// where the operator's dashboard puts its own staff page: managing people is
// configuration, not day-to-day selling.
settingsNav.add({
  key: 'settings.team',
  label: i18n.t('nav.team'),
  path: '/team',
  icon: UsersRoundIcon,
  group: 'team',
  position: 100,
  subject: 'seller_profile',
  action: 'update',
})

// The seller's own legal documents. Under settings because publishing them is
// configuration a seller does once, not day-to-day selling — and because what
// they must publish is the marketplace's onboarding checklist, which links
// here.
settingsNav.add({
  key: 'settings.policies',
  label: i18n.t('nav.policies'),
  path: '/policies',
  icon: ScrollTextIcon,
  group: 'legal',
  position: 100,
  subject: 'seller_profile',
  action: 'update',
})
