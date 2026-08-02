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
