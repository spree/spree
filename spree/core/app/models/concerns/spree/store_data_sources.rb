module Spree
  # Where a store gets its prices and stock levels from.
  #
  # The preference stores the provider's registry **key** rather than a class
  # name, because the same string is written to
  # +spree_line_items.price_source+ — an order has to be able to say where its
  # price came from years later, and a class name is not a stable thing to keep
  # in a data column.
  #
  # An unregistered key resolves to Internal rather than raising: a provider
  # gem being uninstalled must not take checkout down with it, and the merchant
  # sees the setting fall back in the admin.
  module StoreDataSources
    extend ActiveSupport::Concern

    INTERNAL_KEY = 'internal'.freeze

    included do
      validates :preferred_pricing_provider_failure_policy,
                inclusion: { in: Spree::ProviderFailurePolicy::VALUES }
      validates :preferred_inventory_provider_failure_policy,
                inclusion: { in: Spree::ProviderFailurePolicy::VALUES }
    end

    # Deliberately not memoized. A store object outlives a preference change —
    # a merchant switching provider in the admin, a job holding a store for
    # hours — and a cached instance would keep answering from the old setting.
    # Construction is a registry lookup and an argless +new+.
    #
    # @return [Spree::PricingProvider::Base]
    def pricing_provider_instance
      resolve_provider(
        Spree.pricing_providers, preferred_pricing_provider, Spree::PricingProvider::Internal
      ).new
    end

    # @return [Spree::InventoryProvider::Base]
    def inventory_provider_instance
      resolve_provider(
        Spree.inventory_providers, preferred_inventory_provider, Spree::InventoryProvider::Internal
      ).new
    end

    # @return [Boolean] true when prices come from Spree's own catalog
    def internal_pricing?
      pricing_provider_instance.is_a?(Spree::PricingProvider::Internal)
    end

    # @return [Boolean] true when stock levels come from Spree's own records
    def internal_inventory?
      inventory_provider_instance.is_a?(Spree::InventoryProvider::Internal)
    end

    # @return [String] 'fallback' or 'strict'
    def pricing_failure_policy
      preferred_pricing_provider_failure_policy.presence ||
        Spree::ProviderFailurePolicy::DEFAULT_PRICING_POLICY
    end

    # @return [String] 'fallback' or 'strict'
    def inventory_failure_policy
      preferred_inventory_provider_failure_policy.presence ||
        Spree::ProviderFailurePolicy::DEFAULT_INVENTORY_POLICY
    end

    private

    def resolve_provider(registry, key, fallback)
      key = key.to_s
      return fallback if key.blank? || key == INTERNAL_KEY

      registry.detect { |provider| provider.key == key } || fallback
    end
  end
end
