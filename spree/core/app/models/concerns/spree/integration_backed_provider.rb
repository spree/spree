module Spree
  # Shared contract for provider classes whose credentials live on a
  # {Spree::Integration}: delivery rates, fulfillment, pricing and inventory.
  #
  # A provider declares only +integration_class+; whether a store may use it,
  # how it is labelled in the admin, and how its credentials are resolved all
  # follow from that. Stating those three rules once means a change to what
  # "connected" means — an expired OAuth grant, say — lands in one place
  # rather than in each provider family.
  module IntegrationBackedProvider
    extend ActiveSupport::Concern

    class_methods do
      # The registry key a merchant's store preference stores (and, for
      # pricing, the value written to +spree_line_items.price_source+).
      # Gems override it to name their system: 'acme_erp', not 'pricing_provider'.
      #
      # @return [String]
      def key
        name.demodulize.underscore
      end

      # The Spree::Integration subclass holding this provider's credentials,
      # as a class name string. Internal providers need none.
      #
      # @return [String, nil]
      def integration_class
        nil
      end

      # Whether the store can use this provider at all — admin pickers hide or
      # prompt-to-connect providers whose integration is not connected.
      #
      # @param store [Spree::Store, nil]
      # @return [Boolean]
      def available_for_store?(store)
        return true if integration_class.blank?

        store.present? && store.integrations.active.exists?(type: integration_class)
      end

      # The name a merchant sees when choosing a provider.
      #
      # A gem's provider is conventionally named for its family
      # (+SpreeEasyPost::PricingProvider+), so demodulizing yields the useless
      # "Pricing Provider" — those derive the label from the gem's outer module
      # instead (+SpreeEasyPost+ → "EasyPost"), matching
      # {Spree::Integration.api_type}.
      #
      # @return [String]
      def provider_name
        leaf = name.demodulize
        outer = name.deconstantize.delete_prefix('Spree')

        return leaf.titleize if outer.blank? || !leaf.end_with?('Provider')

        # Not `titleize` — it would split the gem's own casing
        # ("SpreeEasyPost" → "Easy Post"). Brands that need more than the
        # module name override this method.
        outer.delete_prefix('::')
      end
    end

    # The connected, active integration carrying this provider's credentials.
    #
    # No memoization: provider instances are built fresh per resolution, so an
    # instance-level cache never gets a second hit. A provider consulting this
    # on the catalog read path should do so inside +price_for+ (whose answers
    # {Spree::Pricing::PriceResolution} caches by +cache_ttl+), not +handles?+.
    #
    # @param store [Spree::Store, nil]
    # @return [Spree::Integration, nil]
    def integration_for(store)
      return if self.class.integration_class.blank?

      store&.integrations&.active&.find_by(type: self.class.integration_class)
    end
  end
end
