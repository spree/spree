// This file is auto-generated from the API serializers by `rake typelizer:generate`. Do not edit directly.

/** The built-in values of `ActorKind`. Extensions may add more. */
export const ACTOR_KINDS = ['admin_user', 'api_key'] as const
export type ActorKind = (typeof ACTOR_KINDS)[number] | (string & {})

/** Every value of `ApiKeyType`. */
export const API_KEY_TYPES = ['publishable', 'secret'] as const
export type ApiKeyType = (typeof API_KEY_TYPES)[number]

/** Every value of `CaptureMethod`. */
export const CAPTURE_METHODS = ['checkout', 'on_dispatch', 'manual'] as const
export type CaptureMethod = (typeof CAPTURE_METHODS)[number]

/** Every value of `CatalogPriceSource`. */
export const CATALOG_PRICE_SOURCES = ['explicit', 'automatic', 'base'] as const
export type CatalogPriceSource = (typeof CATALOG_PRICE_SOURCES)[number]

/** The built-in values of `ClaimStatus`. Extensions may add more. */
export const CLAIM_STATUSES = ['open', 'approved', 'resolved', 'denied', 'canceled'] as const
export type ClaimStatus = (typeof CLAIM_STATUSES)[number] | (string & {})

/** Every value of `CollectionRuleMatchPolicy`. */
export const COLLECTION_RULE_MATCH_POLICIES = [
  'is_equal_to',
  'is_not_equal_to',
  'contains',
  'does_not_contain',
] as const
export type CollectionRuleMatchPolicy = (typeof COLLECTION_RULE_MATCH_POLICIES)[number]

/** Every value of `CommissionKind`. */
export const COMMISSION_KINDS = ['percentage', 'fixed'] as const
export type CommissionKind = (typeof COMMISSION_KINDS)[number]

/** Every value of `CompanyInvitationStatus`. */
export const COMPANY_INVITATION_STATUSES = ['pending', 'accepted', 'revoked', 'expired'] as const
export type CompanyInvitationStatus = (typeof COMPANY_INVITATION_STATUSES)[number]

/** Every value of `CompanyKind`. */
export const COMPANY_KINDS = ['company', 'division'] as const
export type CompanyKind = (typeof COMPANY_KINDS)[number]

/** Every value of `ConsentSource`. */
export const CONSENT_SOURCES = [
  'checkout',
  'registration',
  'account',
  'admin',
  'newsletter',
  'anonymization',
  'unknown',
  'import',
  'storefront',
] as const
export type ConsentSource = (typeof CONSENT_SOURCES)[number]

/** Every value of `DataRequestKind`. */
export const DATA_REQUEST_KINDS = ['access', 'erasure'] as const
export type DataRequestKind = (typeof DATA_REQUEST_KINDS)[number]

/** The built-in values of `DataRequestStatus`. Extensions may add more. */
export const DATA_REQUEST_STATUSES = [
  'awaiting_confirmation',
  'pending',
  'processing',
  'completed',
  'failed',
  'lapsed',
] as const
export type DataRequestStatus = (typeof DATA_REQUEST_STATUSES)[number] | (string & {})

/** Every value of `DeliveryStatus`. */
export const DELIVERY_STATUSES = [
  'pending',
  'pre_transit',
  'in_transit',
  'out_for_delivery',
  'available_for_pickup',
  'delivered',
  'return_to_sender',
  'failure',
  'unknown',
] as const
export type DeliveryStatus = (typeof DELIVERY_STATUSES)[number]

/** Every value of `DeliveryZoneMemberType`. */
export const DELIVERY_ZONE_MEMBER_TYPES = ['country', 'state', 'postal_code'] as const
export type DeliveryZoneMemberType = (typeof DELIVERY_ZONE_MEMBER_TYPES)[number]

/** Every value of `DiscountKind`. */
export const DISCOUNT_KINDS = ['promotion', 'manual'] as const
export type DiscountKind = (typeof DISCOUNT_KINDS)[number]

/** Every value of `DocumentNumberFormat`. */
export const DOCUMENT_NUMBER_FORMATS = ['sequential', 'random'] as const
export type DocumentNumberFormat = (typeof DOCUMENT_NUMBER_FORMATS)[number]

/** Every value of `EmailFont`. */
export const EMAIL_FONTS = [
  'inter',
  'system',
  'helvetica',
  'georgia',
  'roboto',
  'lato',
  'merriweather',
] as const
export type EmailFont = (typeof EMAIL_FONTS)[number]

/** Every value of `EmailTemplateKind`. */
export const EMAIL_TEMPLATE_KINDS = ['email', 'layout', 'partial'] as const
export type EmailTemplateKind = (typeof EMAIL_TEMPLATE_KINDS)[number]

/** The built-in values of `ExchangeStatus`. Extensions may add more. */
export const EXCHANGE_STATUSES = [
  'requested',
  'approved',
  'received',
  'fulfilled',
  'canceled',
] as const
export type ExchangeStatus = (typeof EXCHANGE_STATUSES)[number] | (string & {})

/** The built-in values of `FeeKind`. Extensions may add more. */
export const FEE_KINDS = [
  'surcharge',
  'handling',
  'gift_wrap',
  'cod',
  'payment',
  'duty',
  'exchange',
] as const
export type FeeKind = (typeof FEE_KINDS)[number] | (string & {})

/** Every value of `FileUploadVisibility`. */
export const FILE_UPLOAD_VISIBILITIES = ['public', 'private'] as const
export type FileUploadVisibility = (typeof FILE_UPLOAD_VISIBILITIES)[number]

/** The built-in values of `FulfillmentItemStatus`. Extensions may add more. */
export const FULFILLMENT_ITEM_STATUSES = ['on_hand', 'backordered', 'shipped', 'returned'] as const
export type FulfillmentItemStatus = (typeof FULFILLMENT_ITEM_STATUSES)[number] | (string & {})

/** The built-in values of `FulfillmentStatus`. Extensions may add more. */
export const FULFILLMENT_STATUSES = ['unfulfilled', 'fulfilled', 'delivered', 'canceled'] as const
export type FulfillmentStatus = (typeof FULFILLMENT_STATUSES)[number] | (string & {})

/** Every value of `FulfillmentType`. */
export const FULFILLMENT_TYPES = ['shipping', 'digital', 'pickup', 'pickup_point'] as const
export type FulfillmentType = (typeof FULFILLMENT_TYPES)[number]

/** The built-in values of `GiftCardStatus`. Extensions may add more. */
export const GIFT_CARD_STATUSES = [
  'active',
  'partially_redeemed',
  'redeemed',
  'canceled',
  'expired',
] as const
export type GiftCardStatus = (typeof GIFT_CARD_STATUSES)[number] | (string & {})

/** The built-in values of `ImportRowStatus`. Extensions may add more. */
export const IMPORT_ROW_STATUSES = ['pending', 'processing', 'completed', 'failed'] as const
export type ImportRowStatus = (typeof IMPORT_ROW_STATUSES)[number] | (string & {})

/** The built-in values of `ImportStatus`. Extensions may add more. */
export const IMPORT_STATUSES = [
  'pending',
  'mapping',
  'completed_mapping',
  'processing',
  'completed',
  'failed',
] as const
export type ImportStatus = (typeof IMPORT_STATUSES)[number] | (string & {})

/** The built-in values of `InvitationStatus`. Extensions may add more. */
export const INVITATION_STATUSES = ['pending', 'accepted'] as const
export type InvitationStatus = (typeof INVITATION_STATUSES)[number] | (string & {})

/** Every value of `MatchPolicy`. */
export const MATCH_POLICIES = ['all', 'any'] as const
export type MatchPolicy = (typeof MATCH_POLICIES)[number]

/** Every value of `MediaType`. */
export const MEDIA_TYPES = ['image', 'video', 'external_video'] as const
export type MediaType = (typeof MEDIA_TYPES)[number]

/** Every value of `OptionTypeKind`. */
export const OPTION_TYPE_KINDS = ['dropdown', 'color_swatch', 'buttons'] as const
export type OptionTypeKind = (typeof OPTION_TYPE_KINDS)[number]

/** Every value of `OrderFulfillmentStatus`. */
export const ORDER_FULFILLMENT_STATUSES = [
  'backorder',
  'canceled',
  'partial',
  'unfulfilled',
  'fulfilled',
  'delivered',
  'pending',
  'ready',
  'shipped',
] as const
export type OrderFulfillmentStatus = (typeof ORDER_FULFILLMENT_STATUSES)[number]

/** Every value of `OrderPaymentStatus`. */
export const ORDER_PAYMENT_STATUSES = [
  'none',
  'authorized',
  'partially_paid',
  'paid',
  'partially_refunded',
  'refunded',
  'overcharged',
  'voided',
] as const
export type OrderPaymentStatus = (typeof ORDER_PAYMENT_STATUSES)[number]

/** Every value of `OrderStatus`. */
export const ORDER_STATUSES = ['draft', 'placed', 'canceled'] as const
export type OrderStatus = (typeof ORDER_STATUSES)[number]

/** Every value of `PackageTypeKind`. */
export const PACKAGE_TYPE_KINDS = ['box', 'envelope', 'carton', 'pallet', 'container'] as const
export type PackageTypeKind = (typeof PACKAGE_TYPE_KINDS)[number]

/** The built-in values of `PaymentSessionStatus`. Extensions may add more. */
export const PAYMENT_SESSION_STATUSES = [
  'pending',
  'processing',
  'completed',
  'failed',
  'canceled',
  'expired',
] as const
export type PaymentSessionStatus = (typeof PAYMENT_SESSION_STATUSES)[number] | (string & {})

/** The built-in values of `PaymentSetupSessionStatus`. Extensions may add more. */
export const PAYMENT_SETUP_SESSION_STATUSES = [
  'pending',
  'processing',
  'completed',
  'failed',
  'canceled',
  'expired',
] as const
export type PaymentSetupSessionStatus =
  | (typeof PAYMENT_SETUP_SESSION_STATUSES)[number]
  | (string & {})

/** Every value of `PaymentSourceType`. */
export const PAYMENT_SOURCE_TYPES = ['credit_card', 'store_credit', 'payment_source'] as const
export type PaymentSourceType = (typeof PAYMENT_SOURCE_TYPES)[number]

/** The built-in values of `PaymentStatus`. Extensions may add more. */
export const PAYMENT_STATUSES = [
  'checkout',
  'processing',
  'pending',
  'completed',
  'failed',
  'void',
  'invalid',
] as const
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number] | (string & {})

/** Every value of `PayoutScheduleInterval`. */
export const PAYOUT_SCHEDULE_INTERVALS = [
  'daily',
  'weekly',
  'biweekly',
  'monthly',
  'manual',
] as const
export type PayoutScheduleInterval = (typeof PAYOUT_SCHEDULE_INTERVALS)[number]

/** Every value of `PermissionKind`. */
export const PERMISSION_KINDS = ['read', 'write'] as const
export type PermissionKind = (typeof PERMISSION_KINDS)[number]

/** Every value of `PickupStockPolicy`. */
export const PICKUP_STOCK_POLICIES = ['local', 'any'] as const
export type PickupStockPolicy = (typeof PICKUP_STOCK_POLICIES)[number]

/** The built-in values of `PriceListStatus`. Extensions may add more. */
export const PRICE_LIST_STATUSES = ['draft', 'active', 'inactive', 'scheduled'] as const
export type PriceListStatus = (typeof PRICE_LIST_STATUSES)[number] | (string & {})

/** The built-in values of `ProductStatus`. Extensions may add more. */
export const PRODUCT_STATUSES = ['draft', 'active', 'archived', 'proposed', 'rejected'] as const
export type ProductStatus = (typeof PRODUCT_STATUSES)[number] | (string & {})

/** The built-in values of `ProductSubmissionStatus`. Extensions may add more. */
export const PRODUCT_SUBMISSION_STATUSES = ['pending', 'approved', 'rejected', 'withdrawn'] as const
export type ProductSubmissionStatus = (typeof PRODUCT_SUBMISSION_STATUSES)[number] | (string & {})

/** Every value of `ProviderFailurePolicy`. */
export const PROVIDER_FAILURE_POLICIES = ['fallback', 'strict'] as const
export type ProviderFailurePolicy = (typeof PROVIDER_FAILURE_POLICIES)[number]

/** Every value of `PurchaseUnit`. */
export const PURCHASE_UNITS = ['unit', 'carton'] as const
export type PurchaseUnit = (typeof PURCHASE_UNITS)[number]

/** The built-in values of `ReturnStatus`. Extensions may add more. */
export const RETURN_STATUSES = [
  'requested',
  'approved',
  'received',
  'refunded',
  'canceled',
] as const
export type ReturnStatus = (typeof RETURN_STATUSES)[number] | (string & {})

/** The built-in values of `SellerPayoutStatus`. Extensions may add more. */
export const SELLER_PAYOUT_STATUSES = [
  'pending',
  'processing',
  'completed',
  'failed',
  'unresolved',
] as const
export type SellerPayoutStatus = (typeof SELLER_PAYOUT_STATUSES)[number] | (string & {})

/** Every value of `SellerRequirementState`. */
export const SELLER_REQUIREMENT_STATES = ['complete', 'incomplete', 'pending', 'rejected'] as const
export type SellerRequirementState = (typeof SELLER_REQUIREMENT_STATES)[number]

/** The built-in values of `SellerRequirementSubmissionStatus`. Extensions may add more. */
export const SELLER_REQUIREMENT_SUBMISSION_STATUSES = [
  'pending',
  'accepted',
  'rejected',
  'waived',
] as const
export type SellerRequirementSubmissionStatus =
  | (typeof SELLER_REQUIREMENT_SUBMISSION_STATUSES)[number]
  | (string & {})

/** The built-in values of `SellerStatus`. Extensions may add more. */
export const SELLER_STATUSES = [
  'pending',
  'invited',
  'canceled',
  'onboarding',
  'ready_for_review',
  'approved',
  'rejected',
  'suspended',
] as const
export type SellerStatus = (typeof SELLER_STATUSES)[number] | (string & {})

/** Every value of `SellerTransferKind`. */
export const SELLER_TRANSFER_KINDS = ['earning', 'refund_reversal'] as const
export type SellerTransferKind = (typeof SELLER_TRANSFER_KINDS)[number]

/** The built-in values of `SellerTransferStatus`. Extensions may add more. */
export const SELLER_TRANSFER_STATUSES = [
  'pending',
  'processing',
  'completed',
  'failed',
  'unresolved',
] as const
export type SellerTransferStatus = (typeof SELLER_TRANSFER_STATUSES)[number] | (string & {})

/** Every value of `ShippingLabelOwnerType`. */
export const SHIPPING_LABEL_OWNER_TYPES = ['fulfillment', 'return'] as const
export type ShippingLabelOwnerType = (typeof SHIPPING_LABEL_OWNER_TYPES)[number]

/** Every value of `ShippingLabelSource`. */
export const SHIPPING_LABEL_SOURCES = ['purchased', 'uploaded'] as const
export type ShippingLabelSource = (typeof SHIPPING_LABEL_SOURCES)[number]

/** The built-in values of `ShippingLabelStatus`. Extensions may add more. */
export const SHIPPING_LABEL_STATUSES = ['purchased', 'refund_requested', 'refunded'] as const
export type ShippingLabelStatus = (typeof SHIPPING_LABEL_STATUSES)[number] | (string & {})

/** Every value of `StockAvailability`. */
export const STOCK_AVAILABILITIES = ['in_stock', 'out_of_stock'] as const
export type StockAvailability = (typeof STOCK_AVAILABILITIES)[number]

/** The built-in values of `StockLocationKind`. Extensions may add more. */
export const STOCK_LOCATION_KINDS = ['warehouse', 'store', 'fulfillment_center'] as const
export type StockLocationKind = (typeof STOCK_LOCATION_KINDS)[number] | (string & {})

/** Every value of `StockMovementKind`. */
export const STOCK_MOVEMENT_KINDS = [
  'received',
  'allocated',
  'shipped',
  'released',
  'adjusted',
] as const
export type StockMovementKind = (typeof STOCK_MOVEMENT_KINDS)[number]

/** Every value of `StockReceiptLineType`. */
export const STOCK_RECEIPT_LINE_TYPES = ['purchase_order_item', 'stock_transfer_item'] as const
export type StockReceiptLineType = (typeof STOCK_RECEIPT_LINE_TYPES)[number]

/** Every value of `StockReceiptReceivableType`. */
export const STOCK_RECEIPT_RECEIVABLE_TYPES = ['purchase_order', 'stock_transfer'] as const
export type StockReceiptReceivableType = (typeof STOCK_RECEIPT_RECEIVABLE_TYPES)[number]

/** Every value of `StockReceiptRejectionReason`. */
export const STOCK_RECEIPT_REJECTION_REASONS = [
  'damaged',
  'wrong_item',
  'expired',
  'other',
] as const
export type StockReceiptRejectionReason = (typeof STOCK_RECEIPT_REJECTION_REASONS)[number]

/** Every value of `StorefrontAccess`. */
export const STOREFRONT_ACCESSES = ['public', 'prices_hidden', 'login_required'] as const
export type StorefrontAccess = (typeof STOREFRONT_ACCESSES)[number]

/** The built-in values of `TaxExemptionCertificateStatus`. Extensions may add more. */
export const TAX_EXEMPTION_CERTIFICATE_STATUSES = [
  'pending',
  'verified',
  'expired',
  'revoked',
] as const
export type TaxExemptionCertificateStatus =
  | (typeof TAX_EXEMPTION_CERTIFICATE_STATUSES)[number]
  | (string & {})

/** Every value of `TaxIdentifierSource`. */
export const TAX_IDENTIFIER_SOURCES = ['override', 'company', 'customer'] as const
export type TaxIdentifierSource = (typeof TAX_IDENTIFIER_SOURCES)[number]

/** Every value of `TaxIdentifierValidationStatus`. */
export const TAX_IDENTIFIER_VALIDATION_STATUSES = [
  'pending',
  'verified',
  'unverified',
  'unavailable',
  'unsupported',
] as const
export type TaxIdentifierValidationStatus = (typeof TAX_IDENTIFIER_VALIDATION_STATUSES)[number]

/** Every value of `UnitSystem`. */
export const UNIT_SYSTEMS = ['metric', 'imperial'] as const
export type UnitSystem = (typeof UNIT_SYSTEMS)[number]

/** Every built-in value of every status list above. */
export type BuiltInStatus =
  | (typeof CLAIM_STATUSES)[number]
  | (typeof COMPANY_INVITATION_STATUSES)[number]
  | (typeof DATA_REQUEST_STATUSES)[number]
  | (typeof DELIVERY_STATUSES)[number]
  | (typeof EXCHANGE_STATUSES)[number]
  | (typeof FULFILLMENT_ITEM_STATUSES)[number]
  | (typeof FULFILLMENT_STATUSES)[number]
  | (typeof GIFT_CARD_STATUSES)[number]
  | (typeof IMPORT_ROW_STATUSES)[number]
  | (typeof IMPORT_STATUSES)[number]
  | (typeof INVITATION_STATUSES)[number]
  | (typeof ORDER_FULFILLMENT_STATUSES)[number]
  | (typeof ORDER_PAYMENT_STATUSES)[number]
  | (typeof ORDER_STATUSES)[number]
  | (typeof PAYMENT_SESSION_STATUSES)[number]
  | (typeof PAYMENT_SETUP_SESSION_STATUSES)[number]
  | (typeof PAYMENT_STATUSES)[number]
  | (typeof PRICE_LIST_STATUSES)[number]
  | (typeof PRODUCT_STATUSES)[number]
  | (typeof PRODUCT_SUBMISSION_STATUSES)[number]
  | (typeof RETURN_STATUSES)[number]
  | (typeof SELLER_PAYOUT_STATUSES)[number]
  | (typeof SELLER_REQUIREMENT_SUBMISSION_STATUSES)[number]
  | (typeof SELLER_STATUSES)[number]
  | (typeof SELLER_TRANSFER_STATUSES)[number]
  | (typeof SHIPPING_LABEL_STATUSES)[number]
  | (typeof TAX_EXEMPTION_CERTIFICATE_STATUSES)[number]
  | (typeof TAX_IDENTIFIER_VALIDATION_STATUSES)[number]
