import {
  CreditCardIcon,
  GlobeIcon,
  GlobeLockIcon,
  KeyRoundIcon,
  PercentIcon,
  StoreIcon,
  TagIcon,
  UsersRoundIcon,
  WarehouseIcon,
} from 'lucide-react'
import { Subject } from '@/lib/permissions'
import { settingsNav } from '@/lib/settings-nav-registry'

settingsNav.addGroup({ key: 'store', label: 'Store', position: 100 })
settingsNav.addGroup({ key: 'payments', label: 'Payments & taxes', position: 150 })
settingsNav.addGroup({ key: 'fulfillment', label: 'Fulfillment', position: 200 })
settingsNav.addGroup({ key: 'team', label: 'Team & access', position: 300 })

settingsNav.add({
  key: 'settings.store',
  label: 'Store',
  path: '/store',
  icon: StoreIcon,
  group: 'store',
  position: 100,
  subject: Subject.Store,
})

settingsNav.add({
  key: 'settings.payment-methods',
  label: 'Payment methods',
  path: '/payment-methods',
  icon: CreditCardIcon,
  group: 'payments',
  position: 100,
  subject: Subject.PaymentMethod,
})

settingsNav.add({
  key: 'settings.tax-categories',
  label: 'Tax categories',
  path: '/tax-categories',
  icon: PercentIcon,
  group: 'payments',
  position: 200,
  subject: Subject.TaxCategory,
})

settingsNav.add({
  key: 'settings.markets',
  label: 'Markets',
  path: '/markets',
  icon: GlobeIcon,
  group: 'payments',
  position: 300,
  subject: Subject.Market,
})

settingsNav.add({
  key: 'settings.stock-locations',
  label: 'Stock locations',
  path: '/stock-locations',
  icon: WarehouseIcon,
  group: 'fulfillment',
  position: 100,
  subject: Subject.StockLocation,
})

settingsNav.add({
  key: 'settings.custom-field-definitions',
  label: 'Custom fields',
  path: '/custom-field-definitions',
  icon: TagIcon,
  group: 'store',
  position: 200,
  subject: Subject.CustomFieldDefinition,
})

settingsNav.add({
  key: 'settings.staff',
  label: 'Staff',
  path: '/staff',
  icon: UsersRoundIcon,
  group: 'team',
  position: 100,
  subject: Subject.AdminUser,
})

settingsNav.add({
  key: 'settings.api-keys',
  label: 'API keys',
  path: '/api-keys',
  icon: KeyRoundIcon,
  group: 'team',
  position: 200,
  subject: Subject.ApiKey,
})

settingsNav.add({
  key: 'settings.allowed-origins',
  label: 'Allowed origins',
  path: '/allowed-origins',
  icon: GlobeLockIcon,
  group: 'team',
  position: 300,
  subject: Subject.AllowedOrigin,
})
