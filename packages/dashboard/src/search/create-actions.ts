import { createActionRegistry, Subject } from '@spree/dashboard-core'
import {
  BoxesIcon,
  Building2Icon,
  FolderTreeIcon,
  GiftIcon,
  LayersIcon,
  PackageIcon,
  ShoppingCartIcon,
  SlidersHorizontalIcon,
  StoreIcon,
  TagIcon,
  TicketPercentIcon,
  UserIcon,
  UsersRoundIcon,
} from 'lucide-react'

// Each entry teaches the command palette that one resource can be created, so
// "add product" or "new customer" jumps straight to the right page. Destinations
// come in two shapes, matching how the dashboard creates things: a dedicated
// `/new` route, or an index page whose create sheet opens from `?new=true`.
// Plugins register their own the same way (import `createActionRegistry`).

/** Resolves to the singular noun key; `${name}_plural` holds the plural form. */
const noun = (name: string) => `admin.components.command_palette.create.nouns.${name}`

createActionRegistry.add({
  key: 'product',
  labelKey: noun('product'),
  aliasKeys: [noun('product_plural')],
  icon: TagIcon,
  subject: Subject.Product,
  position: 100,
  getRoute: (storeId) => ({ to: `/${storeId}/products/new` }),
})

createActionRegistry.add({
  key: 'category',
  labelKey: noun('category'),
  aliasKeys: [noun('category_plural')],
  icon: FolderTreeIcon,
  subject: Subject.Category,
  position: 110,
  getRoute: (storeId) => ({ to: `/${storeId}/products/categories/new` }),
})

createActionRegistry.add({
  key: 'collection',
  labelKey: noun('collection'),
  aliasKeys: [noun('collection_plural')],
  icon: LayersIcon,
  subject: Subject.Collection,
  position: 120,
  getRoute: (storeId) => ({ to: `/${storeId}/products/collections/new` }),
})

createActionRegistry.add({
  key: 'price_list',
  labelKey: noun('price_list'),
  aliasKeys: [noun('price_list_plural')],
  icon: TagIcon,
  subject: Subject.PriceList,
  position: 130,
  getRoute: (storeId) => ({ to: `/${storeId}/products/price-lists/new` }),
})

createActionRegistry.add({
  key: 'order',
  labelKey: noun('order'),
  aliasKeys: [noun('order_plural')],
  icon: ShoppingCartIcon,
  subject: Subject.Order,
  position: 200,
  getRoute: (storeId) => ({ to: `/${storeId}/orders/new` }),
})

createActionRegistry.add({
  key: 'customer',
  labelKey: noun('customer'),
  aliasKeys: [noun('customer_plural')],
  icon: UserIcon,
  subject: Subject.Customer,
  position: 300,
  getRoute: (storeId) => ({ to: `/${storeId}/customers`, search: { new: true } }),
})

createActionRegistry.add({
  key: 'customer_group',
  labelKey: noun('customer_group'),
  aliasKeys: [noun('customer_group_plural')],
  icon: UsersRoundIcon,
  subject: Subject.CustomerGroup,
  position: 310,
  getRoute: (storeId) => ({ to: `/${storeId}/customers/groups`, search: { new: true } }),
})

createActionRegistry.add({
  key: 'company',
  labelKey: noun('company'),
  aliasKeys: [noun('company_plural')],
  icon: Building2Icon,
  subject: Subject.Company,
  position: 320,
  getRoute: (storeId) => ({ to: `/${storeId}/companies`, search: { new: true } }),
})

createActionRegistry.add({
  key: 'seller',
  labelKey: noun('seller'),
  aliasKeys: [noun('seller_plural')],
  icon: StoreIcon,
  subject: Subject.Seller,
  position: 330,
  getRoute: (storeId) => ({ to: `/${storeId}/sellers`, search: { new: true } }),
})

createActionRegistry.add({
  key: 'promotion',
  labelKey: noun('promotion'),
  aliasKeys: [noun('promotion_plural'), noun('discount')],
  icon: TicketPercentIcon,
  subject: Subject.Promotion,
  position: 400,
  getRoute: (storeId) => ({ to: `/${storeId}/promotions/new` }),
})

createActionRegistry.add({
  key: 'gift_card',
  labelKey: noun('gift_card'),
  aliasKeys: [noun('gift_card_plural')],
  icon: GiftIcon,
  subject: Subject.GiftCard,
  position: 410,
  getRoute: (storeId) => ({ to: `/${storeId}/promotions/gift-cards`, search: { new: true } }),
})

createActionRegistry.add({
  key: 'option_type',
  labelKey: noun('option_type'),
  aliasKeys: [noun('option_type_plural')],
  icon: SlidersHorizontalIcon,
  subject: Subject.OptionType,
  position: 500,
  getRoute: (storeId) => ({ to: `/${storeId}/products/options`, search: { new: true } }),
})

createActionRegistry.add({
  key: 'stock_transfer',
  labelKey: noun('stock_transfer'),
  aliasKeys: [noun('stock_transfer_plural')],
  icon: BoxesIcon,
  subject: Subject.StockTransfer,
  position: 510,
  getRoute: (storeId) => ({ to: `/${storeId}/products/transfers`, search: { new: true } }),
})

createActionRegistry.add({
  key: 'stock_location',
  labelKey: noun('stock_location'),
  aliasKeys: [noun('stock_location_plural')],
  icon: PackageIcon,
  subject: Subject.StockLocation,
  position: 520,
  getRoute: (storeId) => ({ to: `/${storeId}/settings/stock-locations`, search: { new: true } }),
})
