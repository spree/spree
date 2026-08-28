import { Subject, settingsNav } from '@spree/dashboard-core'
import {
  BanknoteIcon,
  ClipboardCheckIcon,
  CreditCardIcon,
  GlobeIcon,
  GlobeLockIcon,
  HandCoinsIcon,
  KeyRoundIcon,
  MailIcon,
  PercentIcon,
  PlugIcon,
  RadioTowerIcon,
  ReceiptTextIcon,
  RotateCcwIcon,
  ScrollTextIcon,
  ShapesIcon,
  ShieldCheckIcon,
  StoreIcon,
  TagIcon,
  TruckIcon,
  UploadIcon,
  UsersRoundIcon,
  WarehouseIcon,
  WebhookIcon,
} from 'lucide-react'

// Built-in entries use `labelKey` so labels re-render on language change —
// see settings-sidebar.tsx for resolution. Plugins can still pass `label`
// directly when they don't bundle their own translation files.
//
// `descriptionKey` is what the settings landing page shows under each entry;
// `keywords` widen search so a merchant typing the word they know ("VAT",
// "SKU") reaches the page named something else.

settingsNav.addGroup({ key: 'store', labelKey: 'admin.settings_nav.groups.store', position: 100 })
settingsNav.addGroup({
  key: 'selling',
  labelKey: 'admin.settings_nav.groups.selling',
  position: 200,
})
settingsNav.addGroup({
  key: 'shipping',
  labelKey: 'admin.settings_nav.groups.shipping',
  position: 300,
})
settingsNav.addGroup({
  key: 'marketplace',
  labelKey: 'admin.settings_nav.groups.marketplace',
  position: 400,
})
settingsNav.addGroup({ key: 'team', labelKey: 'admin.settings_nav.groups.team', position: 500 })
settingsNav.addGroup({
  key: 'developer',
  labelKey: 'admin.settings_nav.groups.developer',
  position: 600,
})

// --- Store ------------------------------------------------------------------

settingsNav.add({
  key: 'settings.store',
  labelKey: 'admin.settings_nav.items.store',
  descriptionKey: 'admin.settings_nav.descriptions.store',
  keywords: ['general', 'name', 'timezone', 'locale', 'units', 'weight', 'currency'],
  path: '/store',
  icon: StoreIcon,
  group: 'store',
  position: 100,
  subject: Subject.Store,
  // Every staff member can READ the store (shell data: name, logo, timezone,
  // currencies); only settings managers should see the page that edits it.
  action: 'update',
})

settingsNav.add({
  key: 'settings.emails',
  labelKey: 'admin.settings_nav.items.emails',
  descriptionKey: 'admin.settings_nav.descriptions.emails',
  keywords: ['notifications', 'transactional', 'sender', 'from address'],
  path: '/emails',
  icon: MailIcon,
  group: 'store',
  position: 200,
  subject: Subject.Store,
  action: 'update',
})

settingsNav.add({
  key: 'settings.policies',
  labelKey: 'admin.settings_nav.items.policies',
  descriptionKey: 'admin.settings_nav.descriptions.policies',
  keywords: ['legal', 'terms', 'privacy', 'returns', 'refund', 'shipping policy'],
  path: '/policies',
  icon: ScrollTextIcon,
  group: 'store',
  position: 250,
  subject: Subject.Policy,
})

settingsNav.add({
  key: 'settings.channels',
  labelKey: 'admin.settings_nav.items.channels',
  descriptionKey: 'admin.settings_nav.descriptions.channels',
  keywords: ['storefront', 'sales channel', 'pos', 'marketplace'],
  path: '/channels',
  icon: RadioTowerIcon,
  group: 'store',
  position: 300,
  subject: Subject.Channel,
})

settingsNav.add({
  key: 'settings.custom-field-definitions',
  labelKey: 'admin.settings_nav.items.custom_field_definitions',
  descriptionKey: 'admin.settings_nav.descriptions.custom_field_definitions',
  keywords: ['metafields', 'attributes', 'extra fields'],
  path: '/custom-field-definitions',
  icon: TagIcon,
  group: 'store',
  position: 400,
  subject: Subject.CustomFieldDefinition,
})

// --- Selling ----------------------------------------------------------------

settingsNav.add({
  key: 'settings.markets',
  labelKey: 'admin.settings_nav.items.markets',
  descriptionKey: 'admin.settings_nav.descriptions.markets',
  keywords: ['countries', 'regions', 'currency', 'international', 'cross-border'],
  path: '/markets',
  icon: GlobeIcon,
  group: 'selling',
  position: 100,
  subject: Subject.Market,
})

settingsNav.add({
  key: 'settings.payment-methods',
  labelKey: 'admin.settings_nav.items.payment_methods',
  descriptionKey: 'admin.settings_nav.descriptions.payment_methods',
  keywords: ['gateway', 'stripe', 'paypal', 'checkout', 'capture'],
  path: '/payment-methods',
  icon: CreditCardIcon,
  group: 'selling',
  position: 200,
  subject: Subject.PaymentMethod,
})

settingsNav.add({
  key: 'settings.tax-categories',
  labelKey: 'admin.settings_nav.items.tax_categories',
  descriptionKey: 'admin.settings_nav.descriptions.tax_categories',
  keywords: ['vat', 'gst', 'sales tax', 'tax class'],
  path: '/tax-categories',
  icon: PercentIcon,
  group: 'selling',
  position: 300,
  subject: Subject.TaxCategory,
})

settingsNav.add({
  key: 'settings.tax-rates',
  labelKey: 'admin.settings_nav.items.tax_rates',
  descriptionKey: 'admin.settings_nav.descriptions.tax_rates',
  keywords: ['vat', 'gst', 'sales tax', 'rate', 'percentage'],
  path: '/tax-rates',
  icon: ReceiptTextIcon,
  group: 'selling',
  position: 400,
  subject: Subject.TaxRate,
})

settingsNav.add({
  key: 'settings.integrations',
  labelKey: 'admin.settings_nav.items.integrations',
  descriptionKey: 'admin.settings_nav.descriptions.integrations',
  keywords: ['apps', 'providers', 'credentials', 'easypost', 'avalara'],
  path: '/integrations',
  icon: PlugIcon,
  group: 'store',
  position: 500,
  subject: Subject.Integration,
})

// --- Shipping & delivery ----------------------------------------------------

settingsNav.add({
  key: 'settings.delivery-profiles',
  labelKey: 'admin.settings_nav.items.delivery_profiles',
  descriptionKey: 'admin.settings_nav.descriptions.delivery_profiles',
  keywords: ['shipping', 'rates', 'zones', 'carriers', 'delivery methods'],
  path: '/delivery-profiles',
  icon: TruckIcon,
  group: 'shipping',
  position: 100,
  subject: Subject.DeliveryProfile,
})

settingsNav.add({
  key: 'settings.stock-locations',
  labelKey: 'admin.settings_nav.items.stock_locations',
  descriptionKey: 'admin.settings_nav.descriptions.stock_locations',
  keywords: ['warehouse', 'inventory', 'fulfillment', 'pickup'],
  path: '/stock-locations',
  icon: WarehouseIcon,
  group: 'shipping',
  position: 200,
  subject: Subject.StockLocation,
})

settingsNav.add({
  key: 'settings.product-types',
  labelKey: 'admin.settings_nav.items.product_types',
  descriptionKey: 'admin.settings_nav.descriptions.product_types',
  keywords: ['templates', 'prototypes', 'product template'],
  path: '/product-types',
  icon: ShapesIcon,
  group: 'shipping',
  position: 300,
  subject: Subject.ProductType,
})

// --- Returns & sellers ------------------------------------------------------

settingsNav.add({
  key: 'settings.reasons',
  labelKey: 'admin.settings_nav.items.reasons',
  descriptionKey: 'admin.settings_nav.descriptions.reasons',
  keywords: ['returns', 'refunds', 'claims', 'rma', 'reason'],
  path: '/reasons',
  icon: RotateCcwIcon,
  group: 'shipping',
  position: 400,
  subject: Subject.ReturnReason,
})

settingsNav.add({
  key: 'settings.payouts',
  labelKey: 'admin.settings_nav.items.payouts',
  descriptionKey: 'admin.settings_nav.descriptions.payouts',
  keywords: ['marketplace', 'sellers', 'payouts', 'stripe', 'schedule'],
  path: '/payouts',
  icon: BanknoteIcon,
  group: 'marketplace',
  position: 100,
  subject: Subject.SellerPayout,
})

settingsNav.add({
  key: 'settings.commission-rates',
  labelKey: 'admin.settings_nav.items.commission_rates',
  descriptionKey: 'admin.settings_nav.descriptions.commission_rates',
  keywords: ['marketplace', 'sellers', 'payouts', 'fees'],
  path: '/commission-rates',
  icon: HandCoinsIcon,
  group: 'marketplace',
  position: 200,
  subject: Subject.CommissionRate,
})

settingsNav.add({
  key: 'settings.seller-requirements',
  labelKey: 'admin.settings_nav.items.seller_requirements',
  descriptionKey: 'admin.settings_nav.descriptions.seller_requirements',
  keywords: ['marketplace', 'onboarding', 'approval', 'checklist'],
  path: '/seller-requirements',
  icon: ClipboardCheckIcon,
  group: 'marketplace',
  position: 300,
  subject: Subject.Seller,
})

// --- Users & permissions ----------------------------------------------------

settingsNav.add({
  key: 'settings.staff',
  labelKey: 'admin.settings_nav.items.staff',
  descriptionKey: 'admin.settings_nav.descriptions.staff',
  keywords: ['users', 'team', 'invite', 'admins'],
  path: '/staff',
  icon: UsersRoundIcon,
  group: 'team',
  position: 100,
  subject: Subject.AdminUser,
})

settingsNav.add({
  key: 'settings.roles',
  labelKey: 'admin.settings_nav.items.roles',
  descriptionKey: 'admin.settings_nav.descriptions.roles',
  keywords: ['permissions', 'access', 'rbac'],
  path: '/roles',
  icon: ShieldCheckIcon,
  group: 'team',
  position: 200,
  subject: Subject.Role,
})

// --- Developer --------------------------------------------------------------

settingsNav.add({
  key: 'settings.api-keys',
  labelKey: 'admin.settings_nav.items.api_keys',
  descriptionKey: 'admin.settings_nav.descriptions.api_keys',
  keywords: ['tokens', 'secret key', 'publishable key', 'scopes'],
  path: '/api-keys',
  icon: KeyRoundIcon,
  group: 'developer',
  position: 100,
  subject: Subject.ApiKey,
})

settingsNav.add({
  key: 'settings.webhooks',
  labelKey: 'admin.settings_nav.items.webhooks',
  descriptionKey: 'admin.settings_nav.descriptions.webhooks',
  keywords: ['events', 'subscriptions', 'callbacks'],
  path: '/webhooks',
  icon: WebhookIcon,
  group: 'developer',
  position: 200,
  subject: Subject.WebhookEndpoint,
})

settingsNav.add({
  key: 'settings.allowed-origins',
  labelKey: 'admin.settings_nav.items.allowed_origins',
  descriptionKey: 'admin.settings_nav.descriptions.allowed_origins',
  keywords: ['cors', 'domains', 'headless'],
  path: '/allowed-origins',
  icon: GlobeLockIcon,
  group: 'developer',
  position: 300,
  subject: Subject.AllowedOrigin,
})

// The page spans import types and the API filters rows per type, but a
// merchant with no write permission anywhere can't run any import — gate the
// entry on products, the most common import subject.
settingsNav.add({
  key: 'settings.imports',
  labelKey: 'admin.settings_nav.items.imports',
  descriptionKey: 'admin.settings_nav.descriptions.imports',
  keywords: ['csv', 'upload', 'bulk', 'migration'],
  path: '/imports',
  icon: UploadIcon,
  group: 'developer',
  position: 400,
  subject: Subject.Product,
  action: 'update',
})
