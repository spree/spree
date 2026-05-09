import { KeyRoundIcon, StoreIcon, UsersRoundIcon, WarehouseIcon } from 'lucide-react'
import { Subject } from '@/lib/permissions'
import { settingsNav } from '@/lib/settings-nav-registry'

settingsNav.addGroup({ key: 'store', label: 'Store', position: 100 })
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
  key: 'settings.stock-locations',
  label: 'Stock locations',
  path: '/stock-locations',
  icon: WarehouseIcon,
  group: 'fulfillment',
  position: 100,
  subject: Subject.StockLocation,
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
