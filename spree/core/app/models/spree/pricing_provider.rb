module Spree
  module PricingProvider
    # The +price_source+ value marking a negotiated (admin-set) line price.
    # Defined here rather than on Spree::LineItem (which aliases it) so the
    # boot-time registry check below does not force the model graph to load
    # before the app's initializers have run.
    MANUAL_PRICE_SOURCE = 'manual'.freeze

    # Registry keys no provider may claim: a provider answering under
    # 'manual' would make negotiated rows indistinguishable from its own.
    RESERVED_KEYS = [MANUAL_PRICE_SOURCE].freeze

    # Refuses reserved provider keys. Called at boot over the registered
    # pricing providers; raises so a misregistered gem fails loudly instead of
    # silently colliding with the manual-price marker.
    #
    # @param providers [Enumerable<Class>] defaults to Spree.pricing_providers
    # @return [void]
    def self.verify_registry!(providers = Spree.pricing_providers)
      offenders = Array(providers).select { |provider| RESERVED_KEYS.include?(provider.key.to_s) }
      return if offenders.empty?

      raise ArgumentError,
            "Pricing provider key(s) #{offenders.map(&:key).uniq.join(', ')} are reserved " \
            "(#{offenders.map(&:name).join(', ')}). Register the provider under a different .key."
    end
  end
end
