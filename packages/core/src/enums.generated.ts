// This file is auto-generated from the API serializers by `rake typelizer:generate`. Do not edit directly.

/** The built-in values of `ActorKind`. Extensions may add more. */
export const ACTOR_KINDS = ['admin_user', 'api_key'] as const
export type ActorKind = (typeof ACTOR_KINDS)[number] | (string & {})

/** The built-in values of `ClaimStatus`. Extensions may add more. */
export const CLAIM_STATUSES = ['open', 'approved', 'resolved', 'denied', 'canceled'] as const
export type ClaimStatus = (typeof CLAIM_STATUSES)[number] | (string & {})

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

/** The built-in values of `FulfillmentItemStatus`. Extensions may add more. */
export const FULFILLMENT_ITEM_STATUSES = ['on_hand', 'backordered', 'shipped', 'returned'] as const
export type FulfillmentItemStatus = (typeof FULFILLMENT_ITEM_STATUSES)[number] | (string & {})

/** The built-in values of `FulfillmentStatus`. Extensions may add more. */
export const FULFILLMENT_STATUSES = ['unfulfilled', 'fulfilled', 'delivered', 'canceled'] as const
export type FulfillmentStatus = (typeof FULFILLMENT_STATUSES)[number] | (string & {})

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

/** The built-in values of `PriceListStatus`. Extensions may add more. */
export const PRICE_LIST_STATUSES = ['draft', 'active', 'inactive', 'scheduled'] as const
export type PriceListStatus = (typeof PRICE_LIST_STATUSES)[number] | (string & {})

/** The built-in values of `ProductStatus`. Extensions may add more. */
export const PRODUCT_STATUSES = ['draft', 'active', 'archived', 'proposed', 'rejected'] as const
export type ProductStatus = (typeof PRODUCT_STATUSES)[number] | (string & {})

/** The built-in values of `ProductSubmissionStatus`. Extensions may add more. */
export const PRODUCT_SUBMISSION_STATUSES = ['pending', 'approved', 'rejected', 'withdrawn'] as const
export type ProductSubmissionStatus = (typeof PRODUCT_SUBMISSION_STATUSES)[number] | (string & {})

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

/** The built-in values of `SellerTransferStatus`. Extensions may add more. */
export const SELLER_TRANSFER_STATUSES = [
  'pending',
  'processing',
  'completed',
  'failed',
  'unresolved',
] as const
export type SellerTransferStatus = (typeof SELLER_TRANSFER_STATUSES)[number] | (string & {})

/** The built-in values of `ShippingLabelStatus`. Extensions may add more. */
export const SHIPPING_LABEL_STATUSES = ['purchased', 'refund_requested', 'refunded'] as const
export type ShippingLabelStatus = (typeof SHIPPING_LABEL_STATUSES)[number] | (string & {})

/** The built-in values of `StockLocationKind`. Extensions may add more. */
export const STOCK_LOCATION_KINDS = ['warehouse', 'store', 'fulfillment_center'] as const
export type StockLocationKind = (typeof STOCK_LOCATION_KINDS)[number] | (string & {})

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
