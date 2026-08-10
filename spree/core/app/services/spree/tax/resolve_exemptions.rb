module Spree
  module Tax
    # Assembles the exemption evidence for a sale, handed to the tax provider
    # as +estimate+'s +exemptions:+ input.
    #
    # Reads the certificates the buyer's company holds for where the goods are
    # going. Only active ones count — verified, and not past their date — so
    # lifecycle is a filter here rather than something the provider has to
    # reason about. Multiple certificates mean multiple entries; one claim
    # reaching an item is enough to exempt it.
    #
    # A consumer sale, or a cart with no destination yet, resolves nothing and
    # is taxed normally. Inventing a claim would be worse than collecting the
    # tax.
    #
    # Swap through +Spree.tax_resolve_exemptions_service+ to read certificates
    # that live somewhere else — a provider's own store (Avalara keeps them),
    # or wherever the merchant already keeps them.
    class ResolveExemptions
      prepend Spree::ServiceModule::Base

      # @param order [Spree::Cart, Spree::Order]
      # @return [Array<Spree::TaxExemption>]
      def call(order:)
        company = order.company
        address = order.tax_address
        return success([]) if company.nil? || address.nil?

        success(
          company.tax_exemption_certificates.active.for_address(address).map do |certificate|
            Spree::TaxExemption.new(
              reason_code: certificate.reason_code,
              certificate_number: certificate.certificate_number,
              country_iso: certificate.country&.iso,
              state_code: certificate.state&.abbr
            )
          end
        )
      end
    end
  end
end
