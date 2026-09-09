/**
 * CanCanCan subject class names — use these constants instead of raw strings
 * to avoid typos in permission checks.
 *
 * Matches the Ruby class names serialized by the /api/v3/admin/me endpoint.
 */
export const Subject = {
  All: 'all',
  Product: 'Spree::Product',
  ProductType: 'Spree::ProductType',
  // The media library. Authorized as product imagery — a merchant who can edit
  // products can manage the files that illustrate them.
  Media: 'Spree::Media',
  Variant: 'Spree::Variant',
  Order: 'Spree::Order',
  Customer: 'Spree::User',
  CustomerGroup: 'Spree::CustomerGroup',
  AdminUser: 'Spree::AdminUser',
  ApiKey: 'Spree::ApiKey',
  AllowedOrigin: 'Spree::AllowedOrigin',
  Store: 'Spree::Store',
  // The store's packaging vocabulary: the box it ships parcels in, and the
  // cartons, pallets and containers a wholesale order leaves on.
  PackageType: 'Spree::PackageType',
  Channel: 'Spree::Channel',
  OrderRoutingRule: 'Spree::OrderRoutingRule',
  // Categories are Spree::Category < Spree::Taxon; abilities are published under
  // the Spree::Taxon subject, so the value stays 'Spree::Taxon' while the key
  // reads as the user-facing resource name.
  Category: 'Spree::Taxon',
  Collection: 'Spree::Collection',
  OptionType: 'Spree::OptionType',
  OptionValue: 'Spree::OptionValue',
  Policy: 'Spree::Policy',
  TaxCategory: 'Spree::TaxCategory',
  TaxRate: 'Spree::TaxRate',
  TaxIdentifier: 'Spree::TaxIdentifier',
  TaxExemptionCertificate: 'Spree::TaxExemptionCertificate',
  Company: 'Spree::Company',
  CompanyAddress: 'Spree::CompanyAddress',
  CompanyMembership: 'Spree::CompanyMembership',
  CompanyInvitation: 'Spree::CompanyInvitation',
  Catalog: 'Spree::Catalog',
  ReturnReason: 'Spree::ReturnReason',
  ClaimReason: 'Spree::ClaimReason',
  RefundReason: 'Spree::RefundReason',
  OrderCancellationReason: 'Spree::OrderCancellationReason',
  CustomFieldDefinition: 'Spree::CustomFieldDefinition',
  Integration: 'Spree::Integration',
  PaymentMethod: 'Spree::PaymentMethod',
  DeliveryMethod: 'Spree::DeliveryMethod',
  DeliveryZone: 'Spree::DeliveryZone',
  DeliveryProfile: 'Spree::DeliveryProfile',
  /** @deprecated Use Subject.DeliveryMethod — removed in Spree 6.1. */
  ShippingMethod: 'Spree::ShippingMethod',
  StockLocation: 'Spree::StockLocation',
  StockLevel: 'Spree::StockLevel',
  /** @deprecated Use Subject.StockLevel — removed in Spree 6.1. */
  StockItem: 'Spree::StockItem',
  StockTransfer: 'Spree::StockTransfer',
  PriceList: 'Spree::PriceList',
  PriceRule: 'Spree::PriceRule',
  Promotion: 'Spree::Promotion',
  PromotionAction: 'Spree::PromotionAction',
  PromotionRule: 'Spree::PromotionRule',
  GiftCard: 'Spree::GiftCard',
  Role: 'Spree::Role',
  Invitation: 'Spree::Invitation',
  Market: 'Spree::Market',
  WebhookEndpoint: 'Spree::WebhookEndpoint',
  WebhookDelivery: 'Spree::WebhookDelivery',
  Wishlist: 'Spree::Wishlist',
  Seller: 'Spree::Seller',
  CommissionRate: 'Spree::CommissionRate',
  CommissionRule: 'Spree::CommissionRule',
  CommissionLine: 'Spree::CommissionLine',
  SellerPayout: 'Spree::SellerPayout',
  SellerTransfer: 'Spree::SellerTransfer',
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
