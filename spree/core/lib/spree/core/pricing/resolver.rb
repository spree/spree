module Spree
  module Pricing
    # @deprecated Use {Spree::Pricing::PriceResolution}; removed in 6.1.
    #
    # Answering a price used to mean walking the store's price lists and
    # falling back to the variant's base price. That is now one engine among
    # several — {Spree::PricingProvider::Internal} — and choosing between them
    # is {PriceResolution}'s job.
    #
    # The contract differs in one way worth knowing before switching: a
    # configured external provider that cannot answer raises
    # {PriceResolution::ProviderUnavailable} under a store's +strict+ pricing
    # policy, where this class could only ever return a price or nil.
    class Resolver
      attr_reader :context

      # @param context [Spree::Pricing::Context]
      def initialize(context)
        @context = context
      end

      # @return [Spree::Price, nil]
      def resolve
        Spree::Deprecation.warn(
          'Spree::Pricing::Resolver is deprecated and will be removed in Spree 6.1. ' \
          'Use Spree::Pricing::PriceResolution.call(context) instead.'
        )

        Spree::Pricing::PriceResolution.call(context)
      end
    end
  end
end
