module Spree
  module Tax
    # Assembles the exemption evidence for a sale, handed to the tax provider
    # as +estimate+'s +exemptions:+ input.
    #
    # Returns nothing yet, because core has nothing to read: exemption
    # certificates arrive with +Spree::TaxExemptionCertificate+, which is gated
    # on the B2B Company model (docs/plans/6.0-tax-provider.md, Phase 7). This
    # body then becomes the certificate lookup it is standing in for, and the
    # provider contract does not change — which is the reason the seam ships
    # first rather than alongside.
    #
    # Until then, exemption works two ways without core storing anything:
    # through the provider's own certificate store (Avalara's, for instance),
    # or by swapping this service through
    # +Spree.tax_resolve_exemptions_service+ to read wherever the merchant's
    # certificates already live. Inventing a claim here would be worse than
    # collecting the tax.
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
