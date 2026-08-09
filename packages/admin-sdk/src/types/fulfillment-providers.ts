/**
 * A registered `Spree::FulfillmentProvider` strategy, as returned by
 * `GET /delivery_methods/fulfillment_providers`. Providers perform the
 * mechanics of a fulfillment (dispatch, tracking, cancellation) — which is a
 * separate choice from the method's delivery profile — one profile can
 * hold methods fulfilled manually, by a carrier integration, or over the
 * counter.
 */
export interface FulfillmentProviderOption {
  /** Ruby class name, e.g. `Spree::FulfillmentProvider::Pickup`. */
  type: string
  /** Human-readable name for display. */
  name: string
  /** `Spree::Integration` subclass holding this provider's credentials, if any. */
  integration_class: string | null
  /** Wire shorthand of the required integration (`easy_post`), matching `integrations.types()`; null when the provider needs no credentials. */
  integration_type: string | null
  /** False when the provider's integration isn't connected for this store — connect it to enable the provider. */
  available: boolean
  /** Whether this provider delivers digitally. */
  digital: boolean
  /** Whether this provider hands goods over at a merchant counter. */
  pickup: boolean
  /** Whether this provider delivers to third-party pickup points. */
  pickup_point: boolean
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
  /** Wire shorthand of the required integration (`easy_post`), matching `integrations.types()`; null when the provider needs no credentials. */
  integration_type: string | null
  /** False when the provider's integration isn't connected for this store — connect it to enable the provider. */
  available: boolean
  /** Whether this provider quotes real shipments — it can only price methods that ship to an address. */
  requires_address: boolean
  /** Whether the method's calculator sets the price. False for carrier providers, which quote live rates. */
  uses_calculator: boolean
  /**
   * Carrier services this store can offer, fetched live from the carrier.
   * Empty when the provider lists none, or when the listing failed — see
   * `service_catalog_error`. Service rows accept free-form values either
   * way, so a method stays configurable.
   */
  service_catalog: DeliveryRateProviderCatalogEntry[]
  /** Why the services could not be listed (the vendor's own message), or null when they were. */
  service_catalog_error: string | null
}

/** One carrier service in a rate provider's catalog. */
export interface DeliveryRateProviderCatalogEntry {
  /** Carrier identifier as the provider's API knows it, e.g. `UPS`. */
  carrier: string
  /** Service identifier as the provider's API knows it, e.g. `Ground`. */
  service: string
  /** Human-readable label for display, e.g. `UPS Ground`. */
  label: string
}
