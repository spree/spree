import { settingsNav } from '@spree/dashboard-core'
import { WarehouseIcon } from 'lucide-react'

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
