/**
 * A registered `Spree::FulfillmentProvider` strategy, as returned by
 * `GET /delivery_methods/fulfillment_providers`. Providers perform the
 * mechanics of a fulfillment (dispatch, tracking, cancellation) — which is a
 * separate choice from the delivery method's `fulfillment_type`, since one
 * type can be handled by several providers (a shipping method might be
 * fulfilled manually, or through a carrier integration).
 */
export interface FulfillmentProviderOption {
  /** Ruby class name, e.g. `Spree::FulfillmentProvider::Pickup`. */
  type: string
  /** Human-readable name for display. */
  name: string
  /** Fulfillment types this provider handles; empty means any type. */
  fulfillment_types: string[]
  /** Whether fulfillments handled by this provider ship to a customer address. */
  requires_address: boolean
}

/**
 * A registered `Spree::DeliveryRateProvider` strategy, as returned by
 * `GET /delivery_methods/rate_providers`. Rate providers decide where a
 * method's price comes from — the built-in Internal provider prices through
 * the method's calculator, while carrier providers quote live rates. Only
 * providers usable by the current store are listed, so a carrier whose
 * integration is not connected never appears.
 */
export interface DeliveryRateProviderOption {
  /** Ruby class name, e.g. `Spree::DeliveryRateProvider::Internal`. */
  type: string
  /** Human-readable name for display. */
  name: string
  /** `Spree::Integration` subclass holding this provider's credentials, if any. */
  integration_class: string | null
  /** Fulfillment types this provider can quote; empty means any type. */
  fulfillment_types: string[]
  /** Whether the method's calculator sets the price. False for carrier providers, which quote live rates. */
  uses_calculator: boolean
}
