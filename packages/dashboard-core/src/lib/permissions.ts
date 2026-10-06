/**
 * Permission subjects — use these constants instead of raw strings to avoid
 * typos in permission checks.
 *
 * Matches the short names the `/me` endpoints serialize (`product`,
 * `customer`), the same shorthand the rest of the API uses for types.
 */
export const Subject = {
  All: 'all',
  Product: 'product',
  ProductType: 'product_type',
  // The media library. Authorized as product imagery — a merchant who can edit
  // products can manage the files that illustrate them.
  Media: 'media',
  Variant: 'variant',
  Order: 'order',
  SavedReport: 'saved_report',
  ReportExport: 'report',
  Customer: 'customer',
  CustomerGroup: 'customer_group',
  AdminUser: 'admin_user',
  ApiKey: 'api_key',
  OauthApplication: 'oauth_application',
  AllowedOrigin: 'allowed_origin',
  Store: 'store',
  // The store's packaging vocabulary: the box it ships parcels in, and the
  // cartons, pallets and containers a wholesale order leaves on.
  PackageType: 'package_type',
  Channel: 'channel',
  OrderRoutingRule: 'order_routing_rule',
  Category: 'category',
  Collection: 'collection',
  OptionType: 'option_type',
  OptionValue: 'option_value',
  Policy: 'policy',
  TaxCategory: 'tax_category',
  TaxRate: 'tax_rate',
  TaxIdentifier: 'tax_identifier',
  TaxExemptionCertificate: 'tax_exemption_certificate',
  Company: 'company',
  CompanyAddress: 'company_address',
  CompanyMembership: 'company_membership',
  CompanyInvitation: 'company_invitation',
  Catalog: 'catalog',
  ReturnReason: 'return_reason',
  ClaimReason: 'claim_reason',
  RefundReason: 'refund_reason',
  OrderCancellationReason: 'order_cancellation_reason',
  CustomFieldDefinition: 'custom_field_definition',
  Integration: 'integration',
  PaymentMethod: 'payment_method',
  DeliveryMethod: 'delivery_method',
  DeliveryZone: 'delivery_zone',
  DeliveryProfile: 'delivery_profile',
  /** @deprecated Use Subject.DeliveryMethod — removed in Spree 6.1. */
  ShippingMethod: 'delivery_method',
  StockLocation: 'stock_location',
  StockLevel: 'stock_level',
  /** @deprecated Use Subject.StockLevel — removed in Spree 6.1. */
  StockItem: 'stock_level',
  StockTransfer: 'stock_transfer',
  StockTransferItem: 'stock_transfer_item',
  Supplier: 'supplier',
  PurchaseOrder: 'purchase_order',
  PurchaseOrderItem: 'purchase_order_item',
  PriceList: 'price_list',
  PriceRule: 'price_rule',
  Promotion: 'promotion',
  PromotionAction: 'promotion_action',
  PromotionRule: 'promotion_rule',
  GiftCard: 'gift_card',
  GiftCardBatch: 'gift_card_batch',
  StoreCredit: 'store_credit',
  StoreCreditEvent: 'store_credit_event',
  Role: 'role',
  Invitation: 'invitation',
  Market: 'market',
  WebhookEndpoint: 'webhook_endpoint',
  EmailTemplate: 'email_template',
  WebhookDelivery: 'webhook_delivery',
  Wishlist: 'wishlist',
  Seller: 'seller',
  CommissionRate: 'commission_rate',
  CommissionRule: 'commission_rule',
  CommissionLine: 'commission_line',
  SellerPayout: 'seller_payout',
  SellerTransfer: 'seller_transfer',
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
