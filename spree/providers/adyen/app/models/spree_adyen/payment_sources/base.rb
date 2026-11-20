module SpreeAdyen
  module PaymentSources
    # What a buyer paid with through Adyen, other than a card saved for reuse.
    # Each stored 5.x name is a one-line subclass, so rows written by 5.x load;
    # the method's display name comes from SpreeAdyen::Variants.
    class Base < ::Spree::PaymentSource
      store_accessor :metadata, :adyen_variant

      # @return [String]
      def self.display_name
        SpreeAdyen::Variants.display_name(name.demodulize) || name.demodulize.titleize
      end
    end
  end
end
