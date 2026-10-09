// This file is auto-generated from Spree's preference declarations by `rake typelizer:generate`. Do not edit directly.
import type DeliveryMethodRule from './generated/DeliveryMethodRule'

/** `Resource` with its `preferences` typed by its `type`, one member per entry of `Map`. */
type Narrowed<Resource, Map> = {
  [Type in keyof Map]: Omit<Resource, 'type' | 'preferences'> & {
    type: Type
    preferences: Map[Type]
  }
}[keyof Map]

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
