module Spree
  # What a store wants to happen when an external pricing or inventory system
  # cannot be reached.
  #
  # The two defaults differ on purpose. Selling an item the warehouse turns out
  # not to have is recoverable — the merchant contacts the customer. Charging
  # the wrong price is not: the money moves, and a contract customer billed at
  # list price is a dispute rather than an apology. So inventory falls back to
  # the local snapshot and pricing refuses to proceed.
  module ProviderFailurePolicy
    # - +fallback+  use Spree's own answer and warn
    # - +strict+    fail the step and tell the customer to retry
    VALUES = %w[fallback strict].freeze

    DEFAULT_PRICING_POLICY = 'strict'.freeze
    DEFAULT_INVENTORY_POLICY = 'fallback'.freeze

    # Records that a provider could not answer and Spree used its own figure
    # instead. Emitted from one place because the payload keys are public API
    # (docs/plans/6.0-opentelemetry.md) and must stay PII-safe — an error
    # message can carry order or customer detail, so only its class is sent.
    #
    # @param kind [String] 'pricing' or 'inventory'
    # @param provider [String, nil] the provider's registry key
    # @param store [Spree::Store, nil]
    # @param error [StandardError]
    # @return [void]
    def self.report_fallback(kind:, provider:, store:, error:)
      ActiveSupport::Notifications.instrument(
        'provider.fallback.spree',
        provider: provider,
        kind: kind,
        store_id: store&.id,
        reason: error.class.name
      )
    end
  end
end
