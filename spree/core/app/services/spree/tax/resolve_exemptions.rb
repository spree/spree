module Spree
  module Tax
    # Assembles the exemption evidence for a sale, handed to the tax provider
    # as +estimate+'s +exemptions:+ input.
    #
    # Core resolves nothing: stock Spree stores no exemption certificates, and
    # inventing a claim would be worse than collecting tax. Merchants get
    # working exemption either from their provider's own certificate store
    # (Avalara's, for instance) or by swapping this service through
    # +Spree.tax_resolve_exemptions_service+ to read wherever their
    # certificates live.
    class ResolveExemptions
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Cart, Spree::Order]
      # @return [Array<Spree::TaxExemption>]
      def call(order:)
        success([])
      end
    end
  end
end
