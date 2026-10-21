// Spree Enterprise features, shown as preview pages where the real page will
// be once Enterprise is installed. Spree Enterprise calls
// `enterprisePreviews.remove(key)` and registers its own page under the key.
import { nav, pluginRoutes, Subject, settingsNav } from '@spree/dashboard-core'
import {
  Building2Icon,
  FileTextIcon,
  HistoryIcon,
  LayersIcon,
  StoreIcon,
} from '@spree/dashboard-ui/icons'
import { EnterpriseNavBadge } from '../components/spree/enterprise-nav-badge'
import { EnterprisePreviewPage } from '../components/spree/enterprise-preview-page'
import {
  ENTERPRISE_PREVIEWS_ENABLED,
  type EnterprisePreview,
  enterprisePreviews,
} from '../lib/enterprise-previews'

// Each path is where the Enterprise page will live, so links and bookmarks
// keep working after an upgrade: Enterprise's file route at the same path
// replaces the preview page.
const PREVIEWS: EnterprisePreview[] = [
  {
    key: 'orders.quotes',
    id: 'quotes',
    path: '/orders/quotes',
    placement: { nav: 'orders', position: 150 },
    subject: Subject.Order,
    icon: FileTextIcon,
    benefits: ['negotiate', 'validity', 'convert'],
    steps: ['request', 'price', 'send', 'accept'],
  },
  {
    key: 'companies.onboarding',
    id: 'company_onboarding',
    path: '/companies/onboarding',
    placement: { nav: 'companies', position: 100 },
    subject: Subject.Company,
    icon: Building2Icon,
    benefits: ['checklist', 'dialogue', 'agreement'],
    steps: ['register', 'verify', 'review', 'approve'],
  },
  {
    key: 'sellers.shopify',
    id: 'shopify',
    path: '/sellers/shopify',
    placement: { nav: 'sellers', position: 300 },
    subject: Subject.Seller,
    icon: StoreIcon,
    benefits: ['catalog', 'orders', 'control'],
    steps: ['connect', 'install', 'sync', 'sell'],
  },
  {
    key: 'inventory.lots',
    id: 'lots',
    path: '/inventory/lots',
    placement: { nav: 'inventory', position: 400 },
    subject: Subject.StockLevel,
    icon: LayersIcon,
    benefits: ['stock', 'allocation', 'recall'],
    steps: ['receive', 'allocate', 'ship', 'trace'],
  },
  {
    key: 'settings.audit-log',
    id: 'audit_log',
    path: '/audit-log',
    placement: { settingsGroup: 'team', position: 300 },
    subject: Subject.AdminUser,
    icon: HistoryIcon,
    benefits: ['coverage', 'changes', 'search'],
    steps: ['change', 'record', 'review'],
  },
]

function register(preview: EnterprisePreview) {
  const { placement } = preview
  const labelKey = `admin.enterprise.previews.${preview.id}.nav`

  if ('nav' in placement) {
    nav.addChild(placement.nav, {
      key: preview.key,
      labelKey,
      path: preview.path,
      subject: preview.subject,
      position: placement.position,
      badge: EnterpriseNavBadge,
    })
  } else {
    settingsNav.add({
      key: preview.key,
      labelKey,
      descriptionKey: `admin.enterprise.previews.${preview.id}.subtitle`,
      path: preview.path,
      icon: preview.icon,
      group: placement.settingsGroup,
      position: placement.position,
      subject: preview.subject,
      badge: EnterpriseNavBadge,
    })
  }

  pluginRoutes.add({
    key: preview.key,
    path: 'nav' in placement ? preview.path : `/settings${preview.path}`,
    subject: preview.subject,
    component: () => <EnterprisePreviewPage preview={preview} />,
  })

  enterprisePreviews.add(preview, () => {
    if ('nav' in placement) nav.removeChild(placement.nav, preview.key)
    else settingsNav.remove(preview.key)
    pluginRoutes.remove(preview.key)
  })
}

if (ENTERPRISE_PREVIEWS_ENABLED) PREVIEWS.forEach(register)
