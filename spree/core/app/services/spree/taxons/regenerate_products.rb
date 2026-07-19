module Spree
  module Taxons
    # @deprecated Categories are manual in 6.0 and no longer regenerate membership
    #   from rules — that behavior moved to Spree::Collection. There is no faithful
    #   category target, so this shim warns and no-ops (returns the given taxon).
    #   Use Spree::Collections::RegenerateProducts for collections. Removed in 6.1.
    class RegenerateProducts
      prepend ::Spree::ServiceModule::Base

      # @param taxon [Spree::Category] accepted for signature compatibility; ignored
      # @return [Spree::ServiceModule::Base::Result]
      def call(taxon: nil)
        Spree::Deprecation.warn('Spree::Taxons::RegenerateProducts is deprecated and does nothing in Spree 6.0 — categories are manual. Rule-based membership moved to Spree::Collection; use Spree::Collections::RegenerateProducts. Removed in 6.1.')
        success(taxon)
      end
    end
  end
end
