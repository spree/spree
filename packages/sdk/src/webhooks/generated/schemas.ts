// This file is auto-generated from Spree's event catalog by `rake typelizer:generate`. Do not edit directly.
import { z } from 'zod'
import {
  CartSchema,
  ClaimSchema,
  CompanySchema,
  CompanyInvitationSchema,
  CustomerSchema,
  DataRequestEventSchema,
  DeliverySchema,
  DigitalAssetSchema,
  DigitalLinkSchema,
  ExchangeSchema,
  ExportSchema,
  FulfillmentSchema,
  GiftCardSchema,
  GiftCardBatchSchema,
  ImportSchema,
  ImportRowSchema,
  InvitationSchema,
  LineItemSchema,
  MediaEventSchema,
  NewsletterSubscriberSchema,
  NewsletterSubscriberRequestEventSchema,
  OrderSchema,
  OrderGroupSchema,
  PasswordResetRequestedEventSchema,
  PaymentSchema,
  PaymentSessionSchema,
  PaymentSetupSessionSchema,
  PriceSchema,
  ProductSchema,
  ProductSubmissionSchema,
  PromotionSchema,
  PurchaseOrderEventSchema,
  RefundSchema,
  ReturnSchema,
  SavedReportEventSchema,
  SellerSchema,
  ShippingLabelEventSchema,
  StockLevelSchema,
  StockMovementSchema,
  StockReceiptEventSchema,
  StockReservationSchema,
  StockTransferSchema,
  StoreCreditSchema,
  SupplierEventSchema,
  TaxIdentifierSchema,
  VariantSchema,
  WishlistSchema,
  WishlistItemSchema,
} from '../../zod/generated'

export const WebhookRecordReferenceSchema = z.object({
  id: z.string(),
  created_at: z.string().nullable(),
  updated_at: z.string().nullable(),
})

type WebhookEventName =
  | 'admin_user.password_reset'
  | 'cart.created'
  | 'cart.deleted'
  | 'cart.updated'
  | 'catalog.created'
  | 'catalog.deleted'
  | 'catalog.updated'
  | 'claim.approved'
  | 'claim.canceled'
  | 'claim.created'
  | 'claim.deleted'
  | 'claim.denied'
  | 'claim.opened'
  | 'claim.resolved'
  | 'claim.updated'
  | 'company.created'
  | 'company.deleted'
  | 'company.updated'
  | 'company_invitation.accepted'
  | 'company_invitation.created'
  | 'company_invitation.deleted'
  | 'company_invitation.revoked'
  | 'company_invitation.updated'
  | 'customer.anonymized'
  | 'customer.password_reset'
  | 'customer.password_reset_requested'
  | 'data_request.completed'
  | 'data_request.created'
  | 'data_request.deleted'
  | 'data_request.updated'
  | 'delivery.created'
  | 'delivery.deleted'
  | 'delivery.updated'
  | 'digital.created'
  | 'digital.deleted'
  | 'digital.updated'
  | 'digital_asset.created'
  | 'digital_asset.deleted'
  | 'digital_asset.updated'
  | 'digital_link.created'
  | 'digital_link.deleted'
  | 'digital_link.downloaded'
  | 'digital_link.updated'
  | 'email_template.published'
  | 'email_template.reverted'
  | 'exchange.approved'
  | 'exchange.canceled'
  | 'exchange.created'
  | 'exchange.deleted'
  | 'exchange.fulfilled'
  | 'exchange.received'
  | 'exchange.requested'
  | 'exchange.updated'
  | 'export.created'
  | 'export.deleted'
  | 'export.updated'
  | 'fulfillment.canceled'
  | 'fulfillment.created'
  | 'fulfillment.deleted'
  | 'fulfillment.delivered'
  | 'fulfillment.fulfilled'
  | 'fulfillment.updated'
  | 'gift_card.canceled'
  | 'gift_card.created'
  | 'gift_card.deleted'
  | 'gift_card.partially_redeemed'
  | 'gift_card.redeemed'
  | 'gift_card.updated'
  | 'gift_card_batch.created'
  | 'gift_card_batch.deleted'
  | 'gift_card_batch.updated'
  | 'import.completed'
  | 'import.created'
  | 'import.deleted'
  | 'import.progress'
  | 'import.updated'
  | 'import_row.completed'
  | 'import_row.failed'
  | 'invitation.accepted'
  | 'invitation.created'
  | 'invitation.resent'
  | 'line_item.created'
  | 'line_item.deleted'
  | 'line_item.updated'
  | 'media.created'
  | 'media.deleted'
  | 'media.updated'
  | 'newsletter_subscriber.created'
  | 'newsletter_subscriber.deleted'
  | 'newsletter_subscriber.subscription_requested'
  | 'newsletter_subscriber.unsubscribe_requested'
  | 'newsletter_subscriber.updated'
  | 'newsletter_subscriber.verified'
  | 'order.approved'
  | 'order.canceled'
  | 'order.completed'
  | 'order.created'
  | 'order.deleted'
  | 'order.delivered'
  | 'order.fulfilled'
  | 'order.paid'
  | 'order.placed'
  | 'order.resend_confirmation_email'
  | 'order.resend_digital_links_email'
  | 'order.shipped'
  | 'order.updated'
  | 'order_group.completed'
  | 'order_group.created'
  | 'order_group.deleted'
  | 'order_group.resend_confirmation_email'
  | 'order_group.updated'
  | 'payment.captured'
  | 'payment.completed'
  | 'payment.created'
  | 'payment.deleted'
  | 'payment.paid'
  | 'payment.refunded'
  | 'payment.updated'
  | 'payment.voided'
  | 'payment_session.canceled'
  | 'payment_session.completed'
  | 'payment_session.created'
  | 'payment_session.deleted'
  | 'payment_session.expired'
  | 'payment_session.failed'
  | 'payment_session.processing'
  | 'payment_session.updated'
  | 'payment_setup_session.canceled'
  | 'payment_setup_session.completed'
  | 'payment_setup_session.created'
  | 'payment_setup_session.deleted'
  | 'payment_setup_session.expired'
  | 'payment_setup_session.failed'
  | 'payment_setup_session.processing'
  | 'payment_setup_session.updated'
  | 'price.created'
  | 'price.deleted'
  | 'price.updated'
  | 'product.activated'
  | 'product.approved'
  | 'product.archived'
  | 'product.back_in_stock'
  | 'product.created'
  | 'product.deleted'
  | 'product.drafted'
  | 'product.out_of_stock'
  | 'product.proposed'
  | 'product.rejected'
  | 'product.updated'
  | 'product_submission.created'
  | 'product_submission.deleted'
  | 'product_submission.updated'
  | 'promotion.created'
  | 'promotion.deleted'
  | 'promotion.updated'
  | 'purchase_order.canceled'
  | 'purchase_order.created'
  | 'purchase_order.deleted'
  | 'purchase_order.draft'
  | 'purchase_order.ordered'
  | 'purchase_order.over_received'
  | 'purchase_order.partially_received'
  | 'purchase_order.received'
  | 'purchase_order.updated'
  | 'refund.created'
  | 'refund.deleted'
  | 'refund.updated'
  | 'return.approved'
  | 'return.canceled'
  | 'return.created'
  | 'return.deleted'
  | 'return.received'
  | 'return.refunded'
  | 'return.requested'
  | 'return.updated'
  | 'saved_report.created'
  | 'saved_report.deleted'
  | 'saved_report.updated'
  | 'seller.approved'
  | 'seller.created'
  | 'seller.deleted'
  | 'seller.invited'
  | 'seller.onboarding_reopened'
  | 'seller.onboarding_started'
  | 'seller.rejected'
  | 'seller.submitted_for_review'
  | 'seller.suspended'
  | 'seller.updated'
  | 'seller_payout.completed'
  | 'seller_requirement_submission.accepted'
  | 'seller_requirement_submission.created'
  | 'seller_requirement_submission.deleted'
  | 'seller_requirement_submission.rejected'
  | 'seller_requirement_submission.updated'
  | 'seller_requirement_submission.waived'
  | 'seller_user.password_reset'
  | 'shipment.canceled'
  | 'shipment.shipped'
  | 'shipping_label.created'
  | 'shipping_label.deleted'
  | 'shipping_label.purchased'
  | 'shipping_label.refunded'
  | 'shipping_label.updated'
  | 'stock_item.created'
  | 'stock_item.deleted'
  | 'stock_item.updated'
  | 'stock_level.created'
  | 'stock_level.deleted'
  | 'stock_level.updated'
  | 'stock_movement.created'
  | 'stock_movement.deleted'
  | 'stock_movement.updated'
  | 'stock_receipt.created'
  | 'stock_receipt.deleted'
  | 'stock_receipt.updated'
  | 'stock_reservation.created'
  | 'stock_reservation.deleted'
  | 'stock_reservation.updated'
  | 'stock_transfer.canceled'
  | 'stock_transfer.created'
  | 'stock_transfer.deleted'
  | 'stock_transfer.draft'
  | 'stock_transfer.over_received'
  | 'stock_transfer.partially_received'
  | 'stock_transfer.ready_to_ship'
  | 'stock_transfer.received'
  | 'stock_transfer.shipped'
  | 'stock_transfer.updated'
  | 'store_credit.created'
  | 'store_credit.deleted'
  | 'store_credit.updated'
  | 'supplier.created'
  | 'supplier.deleted'
  | 'supplier.updated'
  | 'tax_exemption_certificate.verified'
  | 'tax_identifier.number_changed'
  | 'user.created'
  | 'user.deleted'
  | 'user.updated'
  | 'variant.created'
  | 'variant.deleted'
  | 'variant.updated'
  | 'wished_item.created'
  | 'wished_item.deleted'
  | 'wished_item.updated'
  | 'wishlist.created'
  | 'wishlist.deleted'
  | 'wishlist.updated'
  | 'wishlist_item.created'
  | 'wishlist_item.deleted'
  | 'wishlist_item.updated'

/** The Zod schema for each webhook event's `data`, for `constructWebhookEvent`'s `schemas` option. */
export const webhookEventSchemas: Readonly<Record<WebhookEventName, z.ZodType>> = {
  'admin_user.password_reset': WebhookRecordReferenceSchema,
  'cart.created': CartSchema,
  'cart.deleted': CartSchema,
  'cart.updated': CartSchema,
  'catalog.created': WebhookRecordReferenceSchema,
  'catalog.deleted': WebhookRecordReferenceSchema,
  'catalog.updated': WebhookRecordReferenceSchema,
  'claim.approved': ClaimSchema,
  'claim.canceled': ClaimSchema,
  'claim.created': ClaimSchema,
  'claim.deleted': ClaimSchema,
  'claim.denied': ClaimSchema,
  'claim.opened': ClaimSchema,
  'claim.resolved': ClaimSchema,
  'claim.updated': ClaimSchema,
  'company.created': CompanySchema,
  'company.deleted': CompanySchema,
  'company.updated': CompanySchema,
  'company_invitation.accepted': CompanyInvitationSchema,
  'company_invitation.created': CompanyInvitationSchema,
  'company_invitation.deleted': CompanyInvitationSchema,
  'company_invitation.revoked': CompanyInvitationSchema,
  'company_invitation.updated': CompanyInvitationSchema,
  'customer.anonymized': CustomerSchema,
  'customer.password_reset': CustomerSchema,
  'customer.password_reset_requested': PasswordResetRequestedEventSchema,
  'data_request.completed': DataRequestEventSchema,
  'data_request.created': DataRequestEventSchema,
  'data_request.deleted': DataRequestEventSchema,
  'data_request.updated': DataRequestEventSchema,
  'delivery.created': DeliverySchema,
  'delivery.deleted': DeliverySchema,
  'delivery.updated': DeliverySchema,
  'digital.created': DigitalAssetSchema,
  'digital.deleted': DigitalAssetSchema,
  'digital.updated': DigitalAssetSchema,
  'digital_asset.created': DigitalAssetSchema,
  'digital_asset.deleted': DigitalAssetSchema,
  'digital_asset.updated': DigitalAssetSchema,
  'digital_link.created': DigitalLinkSchema,
  'digital_link.deleted': DigitalLinkSchema,
  'digital_link.downloaded': DigitalLinkSchema,
  'digital_link.updated': DigitalLinkSchema,
  'email_template.published': WebhookRecordReferenceSchema,
  'email_template.reverted': WebhookRecordReferenceSchema,
  'exchange.approved': ExchangeSchema,
  'exchange.canceled': ExchangeSchema,
  'exchange.created': ExchangeSchema,
  'exchange.deleted': ExchangeSchema,
  'exchange.fulfilled': ExchangeSchema,
  'exchange.received': ExchangeSchema,
  'exchange.requested': ExchangeSchema,
  'exchange.updated': ExchangeSchema,
  'export.created': ExportSchema,
  'export.deleted': ExportSchema,
  'export.updated': ExportSchema,
  'fulfillment.canceled': FulfillmentSchema,
  'fulfillment.created': FulfillmentSchema,
  'fulfillment.deleted': FulfillmentSchema,
  'fulfillment.delivered': FulfillmentSchema,
  'fulfillment.fulfilled': FulfillmentSchema,
  'fulfillment.updated': FulfillmentSchema,
  'gift_card.canceled': GiftCardSchema,
  'gift_card.created': GiftCardSchema,
  'gift_card.deleted': GiftCardSchema,
  'gift_card.partially_redeemed': GiftCardSchema,
  'gift_card.redeemed': GiftCardSchema,
  'gift_card.updated': GiftCardSchema,
  'gift_card_batch.created': GiftCardBatchSchema,
  'gift_card_batch.deleted': GiftCardBatchSchema,
  'gift_card_batch.updated': GiftCardBatchSchema,
  'import.completed': ImportSchema,
  'import.created': ImportSchema,
  'import.deleted': ImportSchema,
  'import.progress': ImportSchema,
  'import.updated': ImportSchema,
  'import_row.completed': ImportRowSchema,
  'import_row.failed': ImportRowSchema,
  'invitation.accepted': InvitationSchema,
  'invitation.created': InvitationSchema,
  'invitation.resent': InvitationSchema,
  'line_item.created': LineItemSchema,
  'line_item.deleted': LineItemSchema,
  'line_item.updated': LineItemSchema,
  'media.created': MediaEventSchema,
  'media.deleted': MediaEventSchema,
  'media.updated': MediaEventSchema,
  'newsletter_subscriber.created': NewsletterSubscriberSchema,
  'newsletter_subscriber.deleted': NewsletterSubscriberSchema,
  'newsletter_subscriber.subscription_requested': NewsletterSubscriberRequestEventSchema,
  'newsletter_subscriber.unsubscribe_requested': NewsletterSubscriberRequestEventSchema,
  'newsletter_subscriber.updated': NewsletterSubscriberSchema,
  'newsletter_subscriber.verified': NewsletterSubscriberSchema,
  'order.approved': OrderSchema,
  'order.canceled': OrderSchema,
  'order.completed': OrderSchema,
  'order.created': OrderSchema,
  'order.deleted': OrderSchema,
  'order.delivered': OrderSchema,
  'order.fulfilled': OrderSchema,
  'order.paid': OrderSchema,
  'order.placed': OrderSchema,
  'order.resend_confirmation_email': OrderSchema,
  'order.resend_digital_links_email': OrderSchema,
  'order.shipped': OrderSchema,
  'order.updated': OrderSchema,
  'order_group.completed': OrderGroupSchema,
  'order_group.created': OrderGroupSchema,
  'order_group.deleted': OrderGroupSchema,
  'order_group.resend_confirmation_email': OrderGroupSchema,
  'order_group.updated': OrderGroupSchema,
  'payment.captured': PaymentSchema,
  'payment.completed': PaymentSchema,
  'payment.created': PaymentSchema,
  'payment.deleted': PaymentSchema,
  'payment.paid': PaymentSchema,
  'payment.refunded': PaymentSchema,
  'payment.updated': PaymentSchema,
  'payment.voided': PaymentSchema,
  'payment_session.canceled': PaymentSessionSchema,
  'payment_session.completed': PaymentSessionSchema,
  'payment_session.created': PaymentSessionSchema,
  'payment_session.deleted': PaymentSessionSchema,
  'payment_session.expired': PaymentSessionSchema,
  'payment_session.failed': PaymentSessionSchema,
  'payment_session.processing': PaymentSessionSchema,
  'payment_session.updated': PaymentSessionSchema,
  'payment_setup_session.canceled': PaymentSetupSessionSchema,
  'payment_setup_session.completed': PaymentSetupSessionSchema,
  'payment_setup_session.created': PaymentSetupSessionSchema,
  'payment_setup_session.deleted': PaymentSetupSessionSchema,
  'payment_setup_session.expired': PaymentSetupSessionSchema,
  'payment_setup_session.failed': PaymentSetupSessionSchema,
  'payment_setup_session.processing': PaymentSetupSessionSchema,
  'payment_setup_session.updated': PaymentSetupSessionSchema,
  'price.created': PriceSchema,
  'price.deleted': PriceSchema,
  'price.updated': PriceSchema,
  'product.activated': ProductSchema,
  'product.approved': ProductSchema,
  'product.archived': ProductSchema,
  'product.back_in_stock': ProductSchema,
  'product.created': ProductSchema,
  'product.deleted': ProductSchema,
  'product.drafted': ProductSchema,
  'product.out_of_stock': ProductSchema,
  'product.proposed': ProductSchema,
  'product.rejected': ProductSchema,
  'product.updated': ProductSchema,
  'product_submission.created': ProductSubmissionSchema,
  'product_submission.deleted': ProductSubmissionSchema,
  'product_submission.updated': ProductSubmissionSchema,
  'promotion.created': PromotionSchema,
  'promotion.deleted': PromotionSchema,
  'promotion.updated': PromotionSchema,
  'purchase_order.canceled': PurchaseOrderEventSchema,
  'purchase_order.created': PurchaseOrderEventSchema,
  'purchase_order.deleted': PurchaseOrderEventSchema,
  'purchase_order.draft': PurchaseOrderEventSchema,
  'purchase_order.ordered': PurchaseOrderEventSchema,
  'purchase_order.over_received': PurchaseOrderEventSchema,
  'purchase_order.partially_received': PurchaseOrderEventSchema,
  'purchase_order.received': PurchaseOrderEventSchema,
  'purchase_order.updated': PurchaseOrderEventSchema,
  'refund.created': RefundSchema,
  'refund.deleted': RefundSchema,
  'refund.updated': RefundSchema,
  'return.approved': ReturnSchema,
  'return.canceled': ReturnSchema,
  'return.created': ReturnSchema,
  'return.deleted': ReturnSchema,
  'return.received': ReturnSchema,
  'return.refunded': ReturnSchema,
  'return.requested': ReturnSchema,
  'return.updated': ReturnSchema,
  'saved_report.created': SavedReportEventSchema,
  'saved_report.deleted': SavedReportEventSchema,
  'saved_report.updated': SavedReportEventSchema,
  'seller.approved': SellerSchema,
  'seller.created': SellerSchema,
  'seller.deleted': SellerSchema,
  'seller.invited': SellerSchema,
  'seller.onboarding_reopened': SellerSchema,
  'seller.onboarding_started': SellerSchema,
  'seller.rejected': SellerSchema,
  'seller.submitted_for_review': SellerSchema,
  'seller.suspended': SellerSchema,
  'seller.updated': SellerSchema,
  'seller_payout.completed': WebhookRecordReferenceSchema,
  'seller_requirement_submission.accepted': WebhookRecordReferenceSchema,
  'seller_requirement_submission.created': WebhookRecordReferenceSchema,
  'seller_requirement_submission.deleted': WebhookRecordReferenceSchema,
  'seller_requirement_submission.rejected': WebhookRecordReferenceSchema,
  'seller_requirement_submission.updated': WebhookRecordReferenceSchema,
  'seller_requirement_submission.waived': WebhookRecordReferenceSchema,
  'seller_user.password_reset': WebhookRecordReferenceSchema,
  'shipment.canceled': FulfillmentSchema,
  'shipment.shipped': FulfillmentSchema,
  'shipping_label.created': ShippingLabelEventSchema,
  'shipping_label.deleted': ShippingLabelEventSchema,
  'shipping_label.purchased': ShippingLabelEventSchema,
  'shipping_label.refunded': ShippingLabelEventSchema,
  'shipping_label.updated': ShippingLabelEventSchema,
  'stock_item.created': StockLevelSchema,
  'stock_item.deleted': StockLevelSchema,
  'stock_item.updated': StockLevelSchema,
  'stock_level.created': StockLevelSchema,
  'stock_level.deleted': StockLevelSchema,
  'stock_level.updated': StockLevelSchema,
  'stock_movement.created': StockMovementSchema,
  'stock_movement.deleted': StockMovementSchema,
  'stock_movement.updated': StockMovementSchema,
  'stock_receipt.created': StockReceiptEventSchema,
  'stock_receipt.deleted': StockReceiptEventSchema,
  'stock_receipt.updated': StockReceiptEventSchema,
  'stock_reservation.created': StockReservationSchema,
  'stock_reservation.deleted': StockReservationSchema,
  'stock_reservation.updated': StockReservationSchema,
  'stock_transfer.canceled': StockTransferSchema,
  'stock_transfer.created': StockTransferSchema,
  'stock_transfer.deleted': StockTransferSchema,
  'stock_transfer.draft': StockTransferSchema,
  'stock_transfer.over_received': StockTransferSchema,
  'stock_transfer.partially_received': StockTransferSchema,
  'stock_transfer.ready_to_ship': StockTransferSchema,
  'stock_transfer.received': StockTransferSchema,
  'stock_transfer.shipped': StockTransferSchema,
  'stock_transfer.updated': StockTransferSchema,
  'store_credit.created': StoreCreditSchema,
  'store_credit.deleted': StoreCreditSchema,
  'store_credit.updated': StoreCreditSchema,
  'supplier.created': SupplierEventSchema,
  'supplier.deleted': SupplierEventSchema,
  'supplier.updated': SupplierEventSchema,
  'tax_exemption_certificate.verified': WebhookRecordReferenceSchema,
  'tax_identifier.number_changed': TaxIdentifierSchema,
  'user.created': CustomerSchema,
  'user.deleted': CustomerSchema,
  'user.updated': CustomerSchema,
  'variant.created': VariantSchema,
  'variant.deleted': VariantSchema,
  'variant.updated': VariantSchema,
  'wished_item.created': WishlistItemSchema,
  'wished_item.deleted': WishlistItemSchema,
  'wished_item.updated': WishlistItemSchema,
  'wishlist.created': WishlistSchema,
  'wishlist.deleted': WishlistSchema,
  'wishlist.updated': WishlistSchema,
  'wishlist_item.created': WishlistItemSchema,
  'wishlist_item.deleted': WishlistItemSchema,
  'wishlist_item.updated': WishlistItemSchema,
}
