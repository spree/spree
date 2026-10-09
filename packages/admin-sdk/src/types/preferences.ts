// This file is auto-generated from Spree's preference declarations by `rake typelizer:generate`. Do not edit directly.
import type CommissionRule from './generated/CommissionRule'
import type DeliveryMethodRule from './generated/DeliveryMethodRule'
import type Integration from './generated/Integration'
import type OrderRoutingRule from './generated/OrderRoutingRule'
import type PaymentMethod from './generated/PaymentMethod'
import type PriceRule from './generated/PriceRule'
import type PromotionRule from './generated/PromotionRule'
import type SellerRequirement from './generated/SellerRequirement'

/** `Resource` with its `preferences` typed by its `type`, one member per entry of `Map`. */
type Narrowed<Resource, Map> = {
  [Type in keyof Map]: Omit<Resource, 'type' | 'preferences'> & {
    type: Type
    preferences: Map[Type]
  }
}[keyof Map]

/** Settings of the `category_rule` commission rule. */
export interface CommissionRuleCategoryRulePreferences {
  /** Prefixed `ctg_` ids. */
  category_ids: Array<string>
}

/** Settings of the `item_total_rule` commission rule. */
export interface CommissionRuleItemTotalRulePreferences {
  /** An amount, as an exact decimal string. */
  min_amount: string | null
  /** An amount, as an exact decimal string. */
  max_amount: string | null
}

/** Settings of the `product_rule` commission rule: none. */
export type CommissionRuleProductRulePreferences = Record<string, never>

/** Settings of the `seller_rule` commission rule. */
export interface CommissionRuleSellerRulePreferences {
  /** Prefixed `sel_` ids. */
  seller_ids: Array<string>
}

/**
 * The settings of each commission rule type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface CommissionRulePreferencesMap {
  category_rule: CommissionRuleCategoryRulePreferences
  item_total_rule: CommissionRuleItemTotalRulePreferences
  product_rule: CommissionRuleProductRulePreferences
  seller_rule: CommissionRuleSellerRulePreferences
}

/** A commission rule whose `preferences` are typed by its `type`. */
export type TypedCommissionRule = Narrowed<CommissionRule, CommissionRulePreferencesMap>

/** Settings of the `digital_delivery` delivery calculator. */
export interface DeliveryCalculatorDigitalDeliveryPreferences {
  amounts: Record<string, string>
  /** An amount, as an exact decimal string. */
  amount: string
  /** Format: `currency`. */
  currency: string
}

/** Settings of the `flat_percent_item_total` delivery calculator. */
export interface DeliveryCalculatorFlatPercentItemTotalPreferences {
  flat_percent: string
}

/** Settings of the `flat_rate` delivery calculator. */
export interface DeliveryCalculatorFlatRatePreferences {
  amounts: Record<string, string>
  /** An amount, as an exact decimal string. */
  amount: string
  /** Format: `currency`. */
  currency: string
}

/** Settings of the `flexi_rate` delivery calculator. */
export interface DeliveryCalculatorFlexiRatePreferences {
  /** An amount, as an exact decimal string. */
  first_item: string
  /** An amount, as an exact decimal string. */
  additional_item: string
  max_items: number
  /** Format: `currency`. */
  currency: string
}

/** Settings of the `per_item` delivery calculator. */
export interface DeliveryCalculatorPerItemPreferences {
  amounts: Record<string, string>
  /** An amount, as an exact decimal string. */
  amount: string
  /** Format: `currency`. */
  currency: string
}

/** Settings of the `price_sack` delivery calculator. */
export interface DeliveryCalculatorPriceSackPreferences {
  /** An amount, as an exact decimal string. */
  minimal_amount: string
  /** An amount, as an exact decimal string. */
  normal_amount: string
  /** An amount, as an exact decimal string. */
  discount_amount: string
  /** Format: `currency`. */
  currency: string
}

/**
 * The settings of each delivery calculator type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface DeliveryCalculatorPreferencesMap {
  digital_delivery: DeliveryCalculatorDigitalDeliveryPreferences
  flat_percent_item_total: DeliveryCalculatorFlatPercentItemTotalPreferences
  flat_rate: DeliveryCalculatorFlatRatePreferences
  flexi_rate: DeliveryCalculatorFlexiRatePreferences
  per_item: DeliveryCalculatorPerItemPreferences
  price_sack: DeliveryCalculatorPriceSackPreferences
}

/** Settings of the `channel_rule` delivery method rule. */
export interface DeliveryMethodRuleChannelRulePreferences {
  /** Prefixed `ch_` ids. */
  channel_ids: Array<string>
}

/** Settings of the `company_rule` delivery method rule. */
export interface DeliveryMethodRuleCompanyRulePreferences {
  company_orders_only: boolean
}

/** Settings of the `excluded_products_rule` delivery method rule: none. */
export type DeliveryMethodRuleExcludedProductsRulePreferences = Record<string, never>

/** Settings of the `item_total_rule` delivery method rule. */
export interface DeliveryMethodRuleItemTotalRulePreferences {
  /** An amount, as an exact decimal string. */
  minimum_amount: string | null
  /** An amount, as an exact decimal string. */
  maximum_amount: string | null
}

/** Settings of the `volume_rule` delivery method rule. */
export interface DeliveryMethodRuleVolumeRulePreferences {
  minimum_volume: string | null
  maximum_volume: string | null
}

/** Settings of the `weight_rule` delivery method rule. */
export interface DeliveryMethodRuleWeightRulePreferences {
  minimum_weight: string | null
  maximum_weight: string | null
}

/**
 * The settings of each delivery method rule type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface DeliveryMethodRulePreferencesMap {
  channel_rule: DeliveryMethodRuleChannelRulePreferences
  company_rule: DeliveryMethodRuleCompanyRulePreferences
  excluded_products_rule: DeliveryMethodRuleExcludedProductsRulePreferences
  item_total_rule: DeliveryMethodRuleItemTotalRulePreferences
  volume_rule: DeliveryMethodRuleVolumeRulePreferences
  weight_rule: DeliveryMethodRuleWeightRulePreferences
}

/** A delivery method rule whose `preferences` are typed by its `type`. */
export type TypedDeliveryMethodRule = Narrowed<DeliveryMethodRule, DeliveryMethodRulePreferencesMap>

/**
 * The settings of each integration type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
// biome-ignore lint/suspicious/noEmptyInterface: extensions add their types by declaration merging
export interface IntegrationPreferencesMap {}

/** An integration whose `preferences` are typed by its `type`. */
export type TypedIntegration = Narrowed<Integration, IntegrationPreferencesMap>

/** Settings of the `default_location` order routing rule: none. */
export type OrderRoutingRuleDefaultLocationPreferences = Record<string, never>

/** Settings of the `minimize_splits` order routing rule: none. */
export type OrderRoutingRuleMinimizeSplitsPreferences = Record<string, never>

/** Settings of the `preferred_location` order routing rule: none. */
export type OrderRoutingRulePreferredLocationPreferences = Record<string, never>

/**
 * The settings of each order routing rule type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface OrderRoutingRulePreferencesMap {
  default_location: OrderRoutingRuleDefaultLocationPreferences
  minimize_splits: OrderRoutingRuleMinimizeSplitsPreferences
  preferred_location: OrderRoutingRulePreferredLocationPreferences
}

/** An order routing rule whose `preferences` are typed by its `type`. */
export type TypedOrderRoutingRule = Narrowed<OrderRoutingRule, OrderRoutingRulePreferencesMap>

/** Settings of the `bogus` payment method. */
export interface PaymentMethodBogusPreferences {
  dummy_key: string
  /** Masked when read (`••••1234`); send it back unchanged to keep it, `null` to clear it. */
  dummy_secret_key: string | null
}

/** Settings of the `check` payment method: none. */
export type PaymentMethodCheckPreferences = Record<string, never>

/** Settings of the `custom_payment_source_method` payment method: none. */
export type PaymentMethodCustomPaymentSourceMethodPreferences = Record<string, never>

/** Settings of the `store_credit` payment method: none. */
export type PaymentMethodStoreCreditPreferences = Record<string, never>

/**
 * The settings of each payment method type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface PaymentMethodPreferencesMap {
  bogus: PaymentMethodBogusPreferences
  check: PaymentMethodCheckPreferences
  custom_payment_source_method: PaymentMethodCustomPaymentSourceMethodPreferences
  store_credit: PaymentMethodStoreCreditPreferences
}

/** A payment method whose `preferences` are typed by its `type`. */
export type TypedPaymentMethod = Narrowed<PaymentMethod, PaymentMethodPreferencesMap>

/** Settings of the `channel_rule` price rule. */
export interface PriceRuleChannelRulePreferences {
  /** Prefixed `ch_` ids. */
  channel_ids: Array<string>
}

/** Settings of the `customer_group_rule` price rule. */
export interface PriceRuleCustomerGroupRulePreferences {
  /** Prefixed `cg_` ids. */
  customer_group_ids: Array<string>
}

/** Settings of the `market_rule` price rule. */
export interface PriceRuleMarketRulePreferences {
  /** Prefixed `mkt_` ids. */
  market_ids: Array<string>
}

/** Settings of the `user_rule` price rule. */
export interface PriceRuleUserRulePreferences {
  /** Prefixed `cust_` ids. */
  user_ids: Array<string>
}

/** Settings of the `volume_rule` price rule. */
export interface PriceRuleVolumeRulePreferences {
  min_quantity: number
  max_quantity: number | null
}

/**
 * The settings of each price rule type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface PriceRulePreferencesMap {
  channel_rule: PriceRuleChannelRulePreferences
  customer_group_rule: PriceRuleCustomerGroupRulePreferences
  market_rule: PriceRuleMarketRulePreferences
  user_rule: PriceRuleUserRulePreferences
  volume_rule: PriceRuleVolumeRulePreferences
}

/** A price rule whose `preferences` are typed by its `type`. */
export type TypedPriceRule = Narrowed<PriceRule, PriceRulePreferencesMap>

/** Settings of the `flat_percent_item_total` promotion calculator. */
export interface PromotionCalculatorFlatPercentItemTotalPreferences {
  flat_percent: string
}

/** Settings of the `flat_rate` promotion calculator. */
export interface PromotionCalculatorFlatRatePreferences {
  /** An amount, as an exact decimal string. */
  amount: string
  /** Format: `currency`. */
  currency: string
  apply_only_on_full_priced_items: boolean
}

/** Settings of the `flexi_rate` promotion calculator. */
export interface PromotionCalculatorFlexiRatePreferences {
  /** An amount, as an exact decimal string. */
  first_item: string
  /** An amount, as an exact decimal string. */
  additional_item: string
  max_items: number
  /** Format: `currency`. */
  currency: string
  apply_only_on_full_priced_items: boolean
}

/** Settings of the `percent_on_line_item` promotion calculator. */
export interface PromotionCalculatorPercentOnLineItemPreferences {
  percent: string
  apply_only_on_full_priced_items: boolean
}

/** Settings of the `tiered_flat_rate` promotion calculator. */
export interface PromotionCalculatorTieredFlatRatePreferences {
  tiers: Array<{ threshold: string; value: string }>
  /** An amount, as an exact decimal string. */
  base_amount: string
  /** Format: `currency`. */
  currency: string
}

/** Settings of the `tiered_percent` promotion calculator. */
export interface PromotionCalculatorTieredPercentPreferences {
  tiers: Array<{ threshold: string; value: string }>
  base_percent: string
}

/**
 * The settings of each promotion calculator type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface PromotionCalculatorPreferencesMap {
  flat_percent_item_total: PromotionCalculatorFlatPercentItemTotalPreferences
  flat_rate: PromotionCalculatorFlatRatePreferences
  flexi_rate: PromotionCalculatorFlexiRatePreferences
  percent_on_line_item: PromotionCalculatorPercentOnLineItemPreferences
  tiered_flat_rate: PromotionCalculatorTieredFlatRatePreferences
  tiered_percent: PromotionCalculatorTieredPercentPreferences
}

/** Settings of the `category` promotion rule. */
export interface PromotionRuleCategoryPreferences {
  match_policy: 'any' | 'all'
}

/** Settings of the `channel` promotion rule. */
export interface PromotionRuleChannelPreferences {
  /** Prefixed `ch_` ids. */
  channel_ids: Array<string>
}

/** Settings of the `country` promotion rule. */
export interface PromotionRuleCountryPreferences {
  country_codes: Array<string>
  country_id: number | null
  /** Format: `iso-country`. */
  country_code: string | null
}

/** Settings of the `currency` promotion rule. */
export interface PromotionRuleCurrencyPreferences {
  /** Format: `currency`. */
  currency: string | null
}

/** Settings of the `customer` promotion rule: none. */
export type PromotionRuleCustomerPreferences = Record<string, never>

/** Settings of the `customer_group` promotion rule. */
export interface PromotionRuleCustomerGroupPreferences {
  /** Prefixed `cg_` ids. */
  customer_group_ids: Array<string>
}

/** Settings of the `customer_logged_in` promotion rule: none. */
export type PromotionRuleCustomerLoggedInPreferences = Record<string, never>

/** Settings of the `first_order` promotion rule: none. */
export type PromotionRuleFirstOrderPreferences = Record<string, never>

/** Settings of the `item_total` promotion rule. */
export interface PromotionRuleItemTotalPreferences {
  /** An amount, as an exact decimal string. */
  amount_min: string
  operator_min: string
  /** An amount, as an exact decimal string. */
  amount_max: string | null
  operator_max: string
}

/** Settings of the `market` promotion rule. */
export interface PromotionRuleMarketPreferences {
  /** Prefixed `mkt_` ids. */
  market_ids: Array<string>
}

/** Settings of the `one_use_per_user` promotion rule: none. */
export type PromotionRuleOneUsePerUserPreferences = Record<string, never>

/** Settings of the `option_value` promotion rule. */
export interface PromotionRuleOptionValuePreferences {
  match_policy: 'any'
  /** Prefixed `optval_` ids. */
  eligible_values: Array<string>
}

/** Settings of the `product` promotion rule. */
export interface PromotionRuleProductPreferences {
  match_policy: 'any' | 'all' | 'none'
}

/**
 * The settings of each promotion rule type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface PromotionRulePreferencesMap {
  category: PromotionRuleCategoryPreferences
  channel: PromotionRuleChannelPreferences
  country: PromotionRuleCountryPreferences
  currency: PromotionRuleCurrencyPreferences
  customer: PromotionRuleCustomerPreferences
  customer_group: PromotionRuleCustomerGroupPreferences
  customer_logged_in: PromotionRuleCustomerLoggedInPreferences
  first_order: PromotionRuleFirstOrderPreferences
  item_total: PromotionRuleItemTotalPreferences
  market: PromotionRuleMarketPreferences
  one_use_per_user: PromotionRuleOneUsePerUserPreferences
  option_value: PromotionRuleOptionValuePreferences
  product: PromotionRuleProductPreferences
}

/** A promotion rule whose `preferences` are typed by its `type`. */
export type TypedPromotionRule = Narrowed<PromotionRule, PromotionRulePreferencesMap>

/** Settings of the `accept_terms` seller requirement. */
export interface SellerRequirementAcceptTermsPreferences {
  terms_body: string | null
  /** Format: `date`. */
  terms_effective_from: string | null
  terms_url: string | null
}

/** Settings of the `attestation` seller requirement: none. */
export type SellerRequirementAttestationPreferences = Record<string, never>

/** Settings of the `billing_address` seller requirement: none. */
export type SellerRequirementBillingAddressPreferences = Record<string, never>

/** Settings of the `complete_profile` seller requirement. */
export interface SellerRequirementCompleteProfilePreferences {
  require_about: boolean
  require_logo: boolean
  require_cover_photo: boolean
  require_contact_email: boolean
}

/** Settings of the `delivery_method` seller requirement: none. */
export type SellerRequirementDeliveryMethodPreferences = Record<string, never>

/** Settings of the `document` seller requirement: none. */
export type SellerRequirementDocumentPreferences = Record<string, never>

/** Settings of the `minimum_products` seller requirement. */
export interface SellerRequirementMinimumProductsPreferences {
  minimum_count: number
}

/** Settings of the `operator_review` seller requirement: none. */
export type SellerRequirementOperatorReviewPreferences = Record<string, never>

/** Settings of the `package_type` seller requirement: none. */
export type SellerRequirementPackageTypePreferences = Record<string, never>

/** Settings of the `payout_account` seller requirement: none. */
export type SellerRequirementPayoutAccountPreferences = Record<string, never>

/** Settings of the `policy` seller requirement: none. */
export type SellerRequirementPolicyPreferences = Record<string, never>

/** Settings of the `required_custom_fields` seller requirement: none. */
export type SellerRequirementRequiredCustomFieldsPreferences = Record<string, never>

/** Settings of the `returns_address` seller requirement: none. */
export type SellerRequirementReturnsAddressPreferences = Record<string, never>

/**
 * The settings of each seller requirement type Spree ships, by `type`. An interface,
 * so an extension types its own by declaration merging.
 */
export interface SellerRequirementPreferencesMap {
  accept_terms: SellerRequirementAcceptTermsPreferences
  attestation: SellerRequirementAttestationPreferences
  billing_address: SellerRequirementBillingAddressPreferences
  complete_profile: SellerRequirementCompleteProfilePreferences
  delivery_method: SellerRequirementDeliveryMethodPreferences
  document: SellerRequirementDocumentPreferences
  minimum_products: SellerRequirementMinimumProductsPreferences
  operator_review: SellerRequirementOperatorReviewPreferences
  package_type: SellerRequirementPackageTypePreferences
  payout_account: SellerRequirementPayoutAccountPreferences
  policy: SellerRequirementPolicyPreferences
  required_custom_fields: SellerRequirementRequiredCustomFieldsPreferences
  returns_address: SellerRequirementReturnsAddressPreferences
}

/** A seller requirement whose `preferences` are typed by its `type`. */
export type TypedSellerRequirement = Narrowed<SellerRequirement, SellerRequirementPreferencesMap>
