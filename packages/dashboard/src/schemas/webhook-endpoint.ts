import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const webhookEndpointFormSchema = z.object({
  name: z.string().trim().optional().nullable(),
  url: z
    .string()
    .min(1, { error: requiredMessage('webhook_endpoint.url') })
    .url(),
  active: z.boolean(),
  // Empty array == subscribe to every event (the model treats `[]` and `['*']`
  // the same). The picker emits an empty array when nothing is selected.
  subscriptions: z.array(z.string().min(1)),
})

export type WebhookEndpointFormValues = z.infer<typeof webhookEndpointFormSchema>

export const DEFAULT_WEBHOOK_ENDPOINT_VALUES: WebhookEndpointFormValues = {
  name: '',
  url: '',
  active: true,
  subscriptions: [],
}

/**
 * Catalog of built-in events Spree core publishes. Sourced from
 * `publish_event` call sites plus the `publishes_lifecycle_events` concern
 * (which auto-fires `<model_name>.created/updated/deleted`).
 *
 * Plugin-published events are not enumerated here — the form's free-text
 * input lets admins type any event name (e.g. `loyalty.points_earned`) so
 * plugins don't need to register UI hints to be subscribable.
 *
 * `labelKey` is an i18n key under `admin.pages.settings.webhooks.event_groups`
 * — consumers resolve it via `t(labelKey)` at render time. The list itself is
 * sorted by the English label so the rendered order matches the en.json file.
 */
export interface WebhookEventGroup {
  labelKey: string
  events: readonly string[]
}

export const WEBHOOK_EVENT_GROUPS: readonly WebhookEventGroup[] = [
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.asset',
    events: ['asset.created', 'asset.deleted', 'asset.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.customer',
    events: [
      'customer.created',
      'customer.deleted',
      'customer.password_reset',
      'customer.password_reset_requested',
      'customer.updated',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.digital',
    events: [
      'digital.created',
      'digital.deleted',
      'digital.updated',
      'digital_link.created',
      'digital_link.deleted',
      'digital_link.updated',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.gift_card',
    events: [
      'gift_card.created',
      'gift_card.deleted',
      'gift_card.partially_redeemed',
      'gift_card.redeemed',
      'gift_card.updated',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.gift_card_batch',
    events: ['gift_card_batch.created', 'gift_card_batch.deleted', 'gift_card_batch.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.import_export',
    events: [
      'export.created',
      'export.deleted',
      'export.updated',
      'import.completed',
      'import.created',
      'import.progress',
      'import_row.completed',
      'import_row.failed',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.invitation',
    events: ['invitation.accepted', 'invitation.created', 'invitation.resent'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.line_item',
    events: ['line_item.created', 'line_item.deleted', 'line_item.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.newsletter_subscriber',
    events: [
      'newsletter_subscriber.created',
      'newsletter_subscriber.deleted',
      'newsletter_subscriber.subscription_requested',
      'newsletter_subscriber.updated',
      'newsletter_subscriber.verified',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.order',
    events: [
      'order.approved',
      'order.canceled',
      'order.completed',
      'order.created',
      'order.deleted',
      'order.paid',
      'order.resumed',
      'order.shipped',
      'order.updated',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.payment',
    events: [
      'payment.completed',
      'payment.created',
      'payment.deleted',
      'payment.paid',
      'payment.updated',
      'payment.voided',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.payment_session',
    events: [
      'payment_session.canceled',
      'payment_session.completed',
      'payment_session.expired',
      'payment_session.failed',
      'payment_session.processing',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.payment_setup_session',
    events: [
      'payment_setup_session.canceled',
      'payment_setup_session.completed',
      'payment_setup_session.expired',
      'payment_setup_session.failed',
      'payment_setup_session.processing',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.price',
    events: ['price.created', 'price.deleted', 'price.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.product',
    events: [
      'product.activated',
      'product.archived',
      'product.back_in_stock',
      'product.created',
      'product.deleted',
      'product.out_of_stock',
      'product.updated',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.promotion',
    events: ['promotion.created', 'promotion.deleted', 'promotion.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.refund',
    events: ['refund.created', 'refund.deleted', 'refund.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.report',
    events: ['report.created', 'report.deleted', 'report.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.return',
    events: [
      'customer_return.created',
      'customer_return.deleted',
      'customer_return.updated',
      'reimbursement.reimbursed',
      'return_authorization.canceled',
      'return_authorization.created',
      'return_authorization.deleted',
      'return_authorization.updated',
      'return_item.canceled',
      'return_item.given',
      'return_item.received',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.shipment',
    events: [
      'shipment.canceled',
      'shipment.created',
      'shipment.deleted',
      'shipment.resumed',
      'shipment.shipped',
      'shipment.updated',
    ],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.stock_item',
    events: ['stock_item.created', 'stock_item.deleted', 'stock_item.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.stock_movement',
    events: ['stock_movement.created', 'stock_movement.deleted', 'stock_movement.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.stock_reservation',
    events: ['stock_reservation.created', 'stock_reservation.deleted', 'stock_reservation.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.stock_transfer',
    events: ['stock_transfer.created', 'stock_transfer.deleted', 'stock_transfer.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.store_credit',
    events: ['store_credit.created', 'store_credit.deleted', 'store_credit.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.variant',
    events: ['variant.created', 'variant.deleted', 'variant.updated'],
  },
  {
    labelKey: 'admin.pages.settings.webhooks.event_groups.wishlist',
    events: [
      'wished_item.created',
      'wished_item.deleted',
      'wished_item.updated',
      'wishlist.created',
      'wishlist.deleted',
      'wishlist.updated',
    ],
  },
]
