import { Subject, settingsNav } from '@spree/dashboard-core'
import {
  CreditCardIcon,
  GlobeIcon,
  GlobeLockIcon,
  KeyRoundIcon,
  MailIcon,
  PercentIcon,
  RadioTowerIcon,
  StoreIcon,
  TagIcon,
  UploadIcon,
  UsersRoundIcon,
  WarehouseIcon,
  WebhookIcon,
} from 'lucide-react'

// Built-in entries use `labelKey` so labels re-render on language change —
// see settings-sidebar.tsx for resolution. Plugins can still pass `label`
// directly when they don't bundle their own translation files.

settingsNav.addGroup({ key: 'store', labelKey: 'admin.settings_nav.groups.store', position: 100 })
settingsNav.addGroup({
  key: 'payments',
  labelKey: 'admin.settings_nav.groups.payments',
  position: 150,
})
settingsNav.addGroup({
  key: 'fulfillment',
  labelKey: 'admin.settings_nav.groups.fulfillment',
  position: 200,
})
settingsNav.addGroup({ key: 'audit', labelKey: 'admin.settings_nav.groups.audit', position: 250 })
settingsNav.addGroup({ key: 'team', labelKey: 'admin.settings_nav.groups.team', position: 300 })

settingsNav.add({
  key: 'settings.store',
  labelKey: 'admin.settings_nav.items.store',
  path: '/store',
  icon: StoreIcon,
  group: 'store',
  position: 100,
  subject: Subject.Store,
})

settingsNav.add({
  key: 'settings.emails',
  labelKey: 'admin.settings_nav.items.emails',
  path: '/emails',
  icon: MailIcon,
  group: 'store',
  position: 125,
  subject: Subject.Store,
})

settingsNav.add({
  key: 'settings.channels',
  labelKey: 'admin.settings_nav.items.channels',
  path: '/channels',
  icon: RadioTowerIcon,
  group: 'store',
  position: 150,
  subject: Subject.Channel,
})

settingsNav.add({
  key: 'settings.payment-methods',
  labelKey: 'admin.settings_nav.items.payment_methods',
  path: '/payment-methods',
  icon: CreditCardIcon,
  group: 'payments',
  position: 100,
  subject: Subject.PaymentMethod,
})

settingsNav.add({
  key: 'settings.tax-categories',
  labelKey: 'admin.settings_nav.items.tax_categories',
  path: '/tax-categories',
  icon: PercentIcon,
  group: 'payments',
  position: 200,
  subject: Subject.TaxCategory,
})

settingsNav.add({
  key: 'settings.markets',
  labelKey: 'admin.settings_nav.items.markets',
  path: '/markets',
  icon: GlobeIcon,
  group: 'payments',
  position: 300,
  subject: Subject.Market,
})

settingsNav.add({
  key: 'settings.stock-locations',
  labelKey: 'admin.settings_nav.items.stock_locations',
  path: '/stock-locations',
  icon: WarehouseIcon,
  group: 'fulfillment',
  position: 100,
  subject: Subject.StockLocation,
})

settingsNav.add({
  key: 'settings.custom-field-definitions',
  labelKey: 'admin.settings_nav.items.custom_field_definitions',
  path: '/custom-field-definitions',
  icon: TagIcon,
  group: 'store',
  position: 200,
  subject: Subject.CustomFieldDefinition,
})

settingsNav.add({
  key: 'settings.staff',
  labelKey: 'admin.settings_nav.items.staff',
  path: '/staff',
  icon: UsersRoundIcon,
  group: 'team',
  position: 100,
  subject: Subject.AdminUser,
})

settingsNav.add({
  key: 'settings.api-keys',
  labelKey: 'admin.settings_nav.items.api_keys',
  path: '/api-keys',
  icon: KeyRoundIcon,
  group: 'team',
  position: 200,
  subject: Subject.ApiKey,
})

settingsNav.add({
  key: 'settings.webhooks',
  labelKey: 'admin.settings_nav.items.webhooks',
  path: '/webhooks',
  icon: WebhookIcon,
  group: 'team',
  position: 250,
  subject: Subject.WebhookEndpoint,
})

settingsNav.add({
  key: 'settings.allowed-origins',
  labelKey: 'admin.settings_nav.items.allowed_origins',
  path: '/allowed-origins',
  icon: GlobeLockIcon,
  group: 'team',
  position: 300,
  subject: Subject.AllowedOrigin,
})

// No `subject`: the page spans import types and the API already filters what
// the caller can see.
settingsNav.add({
  key: 'settings.imports',
  labelKey: 'admin.settings_nav.items.imports',
  path: '/imports',
  icon: UploadIcon,
  group: 'audit',
  position: 100,
})
