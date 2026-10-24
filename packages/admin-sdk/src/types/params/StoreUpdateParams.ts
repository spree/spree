// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { WeightUnit } from '../generated'

export type StoreUpdateParams = {
  name?: string
  admin_locale?: string
  timezone?: string
  weight_unit?: WeightUnit
  unit_system?: 'metric' | 'imperial'
  /**
   * The store-wide default for what anonymous visitors can see. Channels fall back to it when they
   * don't set their own.
   */
  storefront_access?: 'public' | 'prices_hidden' | 'login_required'
  /**
   * The storefront's public URL, the base for links in customer emails. Saving it also completes
   * the storefront setup task.
   */
  storefront_url?: string | null
  /** The store-wide default for guest checkout. Channels fall back to it. */
  guest_checkout?: boolean
  /** Always show a confirmation step in checkout, even when no payment method requires one. */
  always_include_confirm_step?: boolean
  /** Shows a company field on address forms. */
  company_field_enabled?: boolean
  /** Makes a company name mandatory on addresses. */
  address_requires_company?: boolean
  /** Makes a phone number mandatory on customer addresses. */
  address_requires_phone?: boolean
  /**
   * The store-wide default for when a customer is charged rather than only authorized. A payment
   * method's own setting wins when set.
   */
  capture_method?: 'checkout' | 'on_dispatch' | 'manual'
  /** Counts on-hand quantities. Off means everything is treated as always available. */
  track_inventory_levels?: boolean
  /** Holds stock for shoppers while they check out, so the same item can't be sold twice. */
  stock_reservations_enabled?: boolean
  /**
   * On-hand units at or below which a tracked variant counts as low stock on the home screen; 0
   * turns the warning off.
   */
  low_stock_threshold?: number
  /**
   * Calculates tax from the shipping address. When false, tax is calculated from the billing
   * address.
   */
  tax_using_ship_address?: boolean
  /** Records price changes for the EU Omnibus lowest-price-in-30-days display. */
  track_price_history?: boolean
  /** Whether products with no price in the shopper's currency still appear in listings. */
  show_products_without_price?: boolean
  /** Lets more than one variant share the same SKU. */
  disable_sku_validation?: boolean
  /** The store-wide order routing strategy shorthand. Channels fall back to it. */
  order_routing_strategy?: string
  /** Where prices come from: a registered provider key, or `internal`. */
  pricing_provider?: string
  /** Where stock levels come from: a registered provider key, or `internal`. */
  inventory_provider?: string
  /** `strict` refuses to price when the provider cannot answer; `fallback` uses the catalog. */
  pricing_provider_failure_policy?: 'fallback' | 'strict'
  /**
   * `fallback` sells on the local stock snapshot when the provider cannot answer; `strict` refuses.
   */
  inventory_provider_failure_policy?: 'fallback' | 'strict'
  /** Blank means the built-in provider: the marketplace settles by hand. */
  payout_provider?: string
  default_payouts_schedule_interval?: 'daily' | 'weekly' | 'biweekly' | 'monthly' | 'manual'
  /** In the store's currency. */
  default_minimum_payout_amount?: string
  /** Admits a seller as soon as they finish onboarding, with no operator review. */
  auto_approve_sellers?: boolean
  /** Puts a seller product on sale the moment it is submitted, with no review. */
  auto_approve_seller_products?: boolean
  /** Lets sellers attach downloadable files to their own products. */
  seller_digital_assets_enabled?: boolean
  /**
   * The content types a seller's file may have, judged from its bytes. The operator's own uploads
   * are not restricted.
   */
  seller_digital_asset_content_types?: string[]
  /**
   * Sends a seller product already on sale back to review when the seller adds or replaces a file
   * on it.
   */
  review_seller_digital_asset_changes?: boolean
  /** When false, transactional seller emails (approval, payouts and so on) are not sent. */
  send_seller_transactional_emails?: boolean
  /**
   * Tax charged on commission as a fraction (`"0.23"` is 23%), when neither the commission rate nor
   * the tax provider names one.
   */
  default_commission_tax_rate?: string
  /**
   * How document numbers are produced: `sequential` or `random`. Applies to every numbered
   * document.
   */
  document_number_format?: string
  /** Leads every order number. Uppercase letters, digits, dashes and # only. */
  order_number_prefix?: string
  /** Ends every order number. Uppercase letters, digits, dashes and # only. */
  order_number_suffix?: string
  /** The first sequential order number. Only applies before the store's first order. */
  order_number_sequence_start?: number
  /** Whether a digital download link stops working after a number of clicks. */
  limit_digital_download_count?: boolean
  /** How many clicks a download link allows, unless the file sets its own. */
  digital_asset_authorized_clicks?: number
  /** Whether a digital download link expires after a number of days. */
  limit_digital_download_days?: boolean
  /** How many days a download link stays valid, unless the file sets its own. */
  digital_asset_authorized_days?: number
  /** Sender address of every transactional email. */
  mail_from_address?: string
  /** Customer-facing reply-to address shown in the storefront and email footers. */
  customer_support_email?: string | null
  /** Recipient of "new order placed" staff notifications. */
  new_order_notifications_email?: string | null
  /** When false, transactional customer emails (order confirmation and so on) are not sent. */
  send_consumer_transactional_emails?: boolean
  /**
   * Customer email buttons and links, as `#RRGGBB`. Blank keeps the outlined buttons emails ship
   * with.
   */
  email_accent_color?: string | null
  /** Customer email page background, as `#RRGGBB`. */
  email_background_color?: string | null
  /** Customer email card behind the content, as `#RRGGBB`. */
  email_card_color?: string | null
  /** Customer email body text, as `#RRGGBB`. */
  email_text_color?: string | null
  /** Customer email headings and emphasized text, as `#RRGGBB`. */
  email_heading_color?: string | null
  /**
   * Customer email font: `inter`, `system`, `helvetica`, `georgia`, `roboto`, `lato` or
   * `merriweather`.
   */
  email_font?: string | null
  /** A `signed_id` from `files.upload()` for the store logo, or null to remove it. */
  logo_signed_id?: string | null
  /**
   * A `signed_id` from `files.upload()` for the logo in transactional emails, or null to remove it.
   */
  mailer_logo_signed_id?: string | null
}
