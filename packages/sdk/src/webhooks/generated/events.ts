// This file is auto-generated from Spree's event catalog by `rake typelizer:generate`. Do not edit directly.
import type {
  Cart,
  Claim,
  Company,
  CompanyInvitation,
  Customer,
  DataRequestEvent,
  Delivery,
  DigitalAsset,
  DigitalLink,
  Exchange,
  Export,
  Fulfillment,
  GiftCard,
  GiftCardBatch,
  Import,
  ImportRow,
  Invitation,
  LineItem,
  MediaEvent,
  NewsletterSubscriber,
  NewsletterSubscriberRequestEvent,
  Order,
  OrderGroup,
  PasswordResetRequestedEvent,
  Payment,
  PaymentSession,
  PaymentSetupSession,
  Price,
  Product,
  ProductSubmission,
  Promotion,
  PurchaseOrderEvent,
  Refund,
  Return,
  SavedReportEvent,
  Seller,
  ShippingLabelEvent,
  StockLevel,
  StockMovement,
  StockReceiptEvent,
  StockReservation,
  StockTransfer,
  StoreCredit,
  SupplierEvent,
  TaxIdentifier,
  Variant,
  Wishlist,
  WishlistItem,
} from '../../types/generated'

/** The payload of an event whose record has no Store API representation. */
export interface WebhookRecordReference {
  id: string
  created_at: string | null
  updated_at: string | null
}

/**
 * Every webhook event Spree publishes, mapped to the record its `data`
 * carries. An interface, so an extension adds its own events by
 * declaration merging.
 */
export interface WebhookEventMap {
  'admin_user.password_reset': WebhookRecordReference
  /** Carries a live credential: delivered only to endpoints that name this event. */
  'admin_user.password_reset_requested': PasswordResetRequestedEvent
  'cart.created': Cart
  'cart.deleted': Cart
  'cart.updated': Cart
  'catalog.created': WebhookRecordReference
  'catalog.deleted': WebhookRecordReference
  'catalog.updated': WebhookRecordReference
  'claim.approved': Claim
  'claim.canceled': Claim
  'claim.created': Claim
  'claim.deleted': Claim
  'claim.denied': Claim
  'claim.opened': Claim
  'claim.resolved': Claim
  'claim.updated': Claim
  'company.created': Company
  'company.deleted': Company
  'company.updated': Company
  'company_invitation.accepted': CompanyInvitation
  'company_invitation.created': CompanyInvitation
  'company_invitation.deleted': CompanyInvitation
  'company_invitation.revoked': CompanyInvitation
  'company_invitation.updated': CompanyInvitation
  'customer.anonymized': Customer
  'customer.password_reset': Customer
  /** Carries a live credential: delivered only to endpoints that name this event. */
  'customer.password_reset_requested': PasswordResetRequestedEvent
  'data_request.completed': DataRequestEvent
  'data_request.created': DataRequestEvent
  'data_request.deleted': DataRequestEvent
  'data_request.updated': DataRequestEvent
  'delivery.created': Delivery
  'delivery.deleted': Delivery
  'delivery.updated': Delivery
  /** @deprecated Use `digital_asset.created` instead. */
  'digital.created': DigitalAsset
  /** @deprecated Use `digital_asset.deleted` instead. */
  'digital.deleted': DigitalAsset
  /** @deprecated Use `digital_asset.updated` instead. */
  'digital.updated': DigitalAsset
  'digital_asset.created': DigitalAsset
  'digital_asset.deleted': DigitalAsset
  'digital_asset.updated': DigitalAsset
  'digital_link.created': DigitalLink
  'digital_link.deleted': DigitalLink
  'digital_link.downloaded': DigitalLink
  'digital_link.updated': DigitalLink
  'exchange.approved': Exchange
  'exchange.canceled': Exchange
  'exchange.created': Exchange
  'exchange.deleted': Exchange
  'exchange.fulfilled': Exchange
  'exchange.received': Exchange
  'exchange.requested': Exchange
  'exchange.updated': Exchange
  'export.created': Export
  'export.deleted': Export
  'export.updated': Export
  'fulfillment.canceled': Fulfillment
  'fulfillment.created': Fulfillment
  'fulfillment.deleted': Fulfillment
  'fulfillment.delivered': Fulfillment
  'fulfillment.fulfilled': Fulfillment
  'fulfillment.updated': Fulfillment
  'gift_card.canceled': GiftCard
  'gift_card.created': GiftCard
  'gift_card.deleted': GiftCard
  'gift_card.partially_redeemed': GiftCard
  'gift_card.redeemed': GiftCard
  'gift_card.updated': GiftCard
  'gift_card_batch.created': GiftCardBatch
  'gift_card_batch.deleted': GiftCardBatch
  'gift_card_batch.updated': GiftCardBatch
  'import.completed': Import
  'import.created': Import
  'import.deleted': Import
  'import.progress': Import
  'import.updated': Import
  'import_row.completed': ImportRow
  'import_row.failed': ImportRow
  'invitation.accepted': Invitation
  'invitation.created': Invitation
  'invitation.resent': Invitation
  'line_item.created': LineItem
  'line_item.deleted': LineItem
  'line_item.updated': LineItem
  'media.created': MediaEvent
  'media.deleted': MediaEvent
  'media.updated': MediaEvent
  'newsletter_subscriber.created': NewsletterSubscriber
  'newsletter_subscriber.deleted': NewsletterSubscriber
  'newsletter_subscriber.subscription_requested': NewsletterSubscriberRequestEvent
  'newsletter_subscriber.unsubscribe_requested': NewsletterSubscriberRequestEvent
  'newsletter_subscriber.updated': NewsletterSubscriber
  'newsletter_subscriber.verified': NewsletterSubscriber
  'order.approved': Order
  'order.canceled': Order
  /** @deprecated Use `order.placed` instead. */
  'order.completed': Order
  'order.created': Order
  'order.deleted': Order
  'order.delivered': Order
  'order.fulfilled': Order
  'order.paid': Order
  'order.placed': Order
  'order.resend_confirmation_email': Order
  'order.resend_digital_links_email': Order
  'order.shipped': Order
  'order.updated': Order
  'order_group.completed': OrderGroup
  'order_group.created': OrderGroup
  'order_group.deleted': OrderGroup
  'order_group.resend_confirmation_email': OrderGroup
  'order_group.updated': OrderGroup
  'payment.captured': Payment
  'payment.completed': Payment
  'payment.created': Payment
  'payment.deleted': Payment
  'payment.paid': Payment
  'payment.refunded': Payment
  'payment.updated': Payment
  'payment.voided': Payment
  'payment_session.canceled': PaymentSession
  'payment_session.completed': PaymentSession
  'payment_session.created': PaymentSession
  'payment_session.deleted': PaymentSession
  'payment_session.expired': PaymentSession
  'payment_session.failed': PaymentSession
  'payment_session.processing': PaymentSession
  'payment_session.updated': PaymentSession
  'payment_setup_session.canceled': PaymentSetupSession
  'payment_setup_session.completed': PaymentSetupSession
  'payment_setup_session.created': PaymentSetupSession
  'payment_setup_session.deleted': PaymentSetupSession
  'payment_setup_session.expired': PaymentSetupSession
  'payment_setup_session.failed': PaymentSetupSession
  'payment_setup_session.processing': PaymentSetupSession
  'payment_setup_session.updated': PaymentSetupSession
  'price.created': Price
  'price.deleted': Price
  'price.updated': Price
  'product.activated': Product
  'product.approved': Product
  'product.archived': Product
  'product.back_in_stock': Product
  'product.created': Product
  'product.deleted': Product
  'product.drafted': Product
  'product.out_of_stock': Product
  'product.proposed': Product
  'product.rejected': Product
  'product.updated': Product
  'product_submission.created': ProductSubmission
  'product_submission.deleted': ProductSubmission
  'product_submission.updated': ProductSubmission
  'promotion.created': Promotion
  'promotion.deleted': Promotion
  'promotion.updated': Promotion
  'purchase_order.canceled': PurchaseOrderEvent
  'purchase_order.created': PurchaseOrderEvent
  'purchase_order.deleted': PurchaseOrderEvent
  'purchase_order.draft': PurchaseOrderEvent
  'purchase_order.ordered': PurchaseOrderEvent
  'purchase_order.over_received': PurchaseOrderEvent
  'purchase_order.partially_received': PurchaseOrderEvent
  'purchase_order.received': PurchaseOrderEvent
  'purchase_order.updated': PurchaseOrderEvent
  'refund.created': Refund
  'refund.deleted': Refund
  'refund.updated': Refund
  'return.approved': Return
  'return.canceled': Return
  'return.created': Return
  'return.deleted': Return
  'return.received': Return
  'return.refunded': Return
  'return.requested': Return
  'return.updated': Return
  'saved_report.created': SavedReportEvent
  'saved_report.deleted': SavedReportEvent
  'saved_report.updated': SavedReportEvent
  'seller.approved': Seller
  'seller.created': Seller
  'seller.deleted': Seller
  'seller.invited': Seller
  'seller.onboarding_reopened': Seller
  'seller.onboarding_started': Seller
  'seller.rejected': Seller
  'seller.submitted_for_review': Seller
  'seller.suspended': Seller
  'seller.updated': Seller
  'seller_payout.completed': WebhookRecordReference
  'seller_requirement_submission.accepted': WebhookRecordReference
  'seller_requirement_submission.created': WebhookRecordReference
  'seller_requirement_submission.deleted': WebhookRecordReference
  'seller_requirement_submission.rejected': WebhookRecordReference
  'seller_requirement_submission.updated': WebhookRecordReference
  'seller_requirement_submission.waived': WebhookRecordReference
  'seller_user.password_reset': WebhookRecordReference
  /** Carries a live credential: delivered only to endpoints that name this event. */
  'seller_user.password_reset_requested': PasswordResetRequestedEvent
  /** @deprecated Use `fulfillment.canceled` instead. */
  'shipment.canceled': Fulfillment
  /** @deprecated Use `fulfillment.fulfilled` instead. */
  'shipment.shipped': Fulfillment
  'shipping_label.created': ShippingLabelEvent
  'shipping_label.deleted': ShippingLabelEvent
  'shipping_label.purchased': ShippingLabelEvent
  'shipping_label.refunded': ShippingLabelEvent
  'shipping_label.updated': ShippingLabelEvent
  /** @deprecated Use `stock_level.created` instead. */
  'stock_item.created': StockLevel
  /** @deprecated Use `stock_level.deleted` instead. */
  'stock_item.deleted': StockLevel
  /** @deprecated Use `stock_level.updated` instead. */
  'stock_item.updated': StockLevel
  'stock_level.created': StockLevel
  'stock_level.deleted': StockLevel
  'stock_level.updated': StockLevel
  'stock_movement.created': StockMovement
  'stock_movement.deleted': StockMovement
  'stock_movement.updated': StockMovement
  'stock_receipt.created': StockReceiptEvent
  'stock_receipt.deleted': StockReceiptEvent
  'stock_receipt.updated': StockReceiptEvent
  'stock_reservation.created': StockReservation
  'stock_reservation.deleted': StockReservation
  'stock_reservation.updated': StockReservation
  'stock_transfer.canceled': StockTransfer
  'stock_transfer.created': StockTransfer
  'stock_transfer.deleted': StockTransfer
  'stock_transfer.draft': StockTransfer
  'stock_transfer.over_received': StockTransfer
  'stock_transfer.partially_received': StockTransfer
  'stock_transfer.ready_to_ship': StockTransfer
  'stock_transfer.received': StockTransfer
  'stock_transfer.shipped': StockTransfer
  'stock_transfer.updated': StockTransfer
  'store_credit.created': StoreCredit
  'store_credit.deleted': StoreCredit
  'store_credit.updated': StoreCredit
  'supplier.created': SupplierEvent
  'supplier.deleted': SupplierEvent
  'supplier.updated': SupplierEvent
  'tax_exemption_certificate.verified': WebhookRecordReference
  'tax_identifier.number_changed': TaxIdentifier
  'user.created': Customer
  'user.deleted': Customer
  'user.updated': Customer
  'variant.created': Variant
  'variant.deleted': Variant
  'variant.updated': Variant
  /** @deprecated Use `wishlist_item.created` instead. */
  'wished_item.created': WishlistItem
  /** @deprecated Use `wishlist_item.deleted` instead. */
  'wished_item.deleted': WishlistItem
  /** @deprecated Use `wishlist_item.updated` instead. */
  'wished_item.updated': WishlistItem
  'wishlist.created': Wishlist
  'wishlist.deleted': Wishlist
  'wishlist.updated': Wishlist
  'wishlist_item.created': WishlistItem
  'wishlist_item.deleted': WishlistItem
  'wishlist_item.updated': WishlistItem
}
