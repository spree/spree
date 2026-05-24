/**
 * CanCanCan subject class names — use these constants instead of raw strings
 * to avoid typos in permission checks.
 *
 * Matches the Ruby class names serialized by the /api/v3/admin/me endpoint.
 */
export const Subject = {
  All: 'all',
  Product: 'Spree::Product',
  Variant: 'Spree::Variant',
  Order: 'Spree::Order',
  Customer: 'Spree::User',
  CustomerGroup: 'Spree::CustomerGroup',
  AdminUser: 'Spree::AdminUser',
  ApiKey: 'Spree::ApiKey',
  Store: 'Spree::Store',
  Taxon: 'Spree::Taxon',
  Taxonomy: 'Spree::Taxonomy',
  OptionType: 'Spree::OptionType',
  OptionValue: 'Spree::OptionValue',
  TaxCategory: 'Spree::TaxCategory',
  PaymentMethod: 'Spree::PaymentMethod',
  ShippingMethod: 'Spree::ShippingMethod',
  StockLocation: 'Spree::StockLocation',
  StockItem: 'Spree::StockItem',
  StockTransfer: 'Spree::StockTransfer',
  Promotion: 'Spree::Promotion',
  PromotionAction: 'Spree::PromotionAction',
  PromotionRule: 'Spree::PromotionRule',
  GiftCard: 'Spree::GiftCard',
  Market: 'Spree::Market',
  Wishlist: 'Spree::Wishlist',
} as const

export type SubjectName = (typeof Subject)[keyof typeof Subject] | string

/** CanCanCan standard actions */
export const Action = {
  Manage: 'manage',
  Read: 'read',
  Create: 'create',
  Update: 'update',
  Destroy: 'destroy',
} as const

export type ActionName = (typeof Action)[keyof typeof Action] | string
