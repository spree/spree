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
        # Resolved once: #resolved_company is deliberately unmemoized, so
        # reading it again for the activation check would repeat the standing
        # lookup behind it.
        node = order.resolved_company
        # The legal entity, never the node itself: a division holds no
        # certificates, and reading its own would silently lose the exemption.
        company = node&.legal_entity
        address = order.tax_address
        return success([]) if company.nil? || address.nil?
        # An inactive company must not exempt a sale in flight: the
        # certificates stay on file, they just stop applying while the
        # activation policy says the business may not act commercially
        # (docs/plans/6.0-b2b-company-self-registration.md).
        #
        # A placed order is exempt from the question, the way its tax
        # registration is (Purchase::Taxation#resolved_tax_identifier):
        # deactivating a company months later must not restate the tax on a
        # sale that was legitimately exempt when it was placed.
        return success([]) if in_flight?(order) && !Spree.company_activation_policy.active?(node)

        success(
          company.tax_exemption_certificates.active.for_address(address).map do |certificate|
            Spree::TaxExemption.new(
              reason_code: certificate.reason_code,
              certificate_number: certificate.certificate_number,
              country_code: certificate.country_code,
              state_code: certificate.state_code
            )
          end
        )
      end

      private

      # A cart, or an order that has not been placed yet. A completed order is
      # history: its tax has to stay explainable.
      def in_flight?(order)
        !(order.is_a?(Spree::Order) && order.completed?)
      end
    end
  end
end
