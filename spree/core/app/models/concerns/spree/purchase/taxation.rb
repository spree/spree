module Spree
  module Purchase
    # Tax location and pre-tax sums shared by Spree::Cart and Spree::Order.
    module Taxation
      # The address tax is computed against, honoring the
      # tax_using_ship_address preference.
      #
      # @return [Spree::Address, nil]
      def tax_address
        Spree::Config[:tax_using_ship_address] ? ship_address : bill_address
      end

      # @return [Spree::Zone, nil]
      def tax_zone
        @tax_zone ||= Spree::Zone.match(tax_address) || Spree::Zone.default_tax
      end

      # The country whose tax applies. Before the customer enters an address
      # that is the market's own country, which is what lets a storefront show
      # tax-inclusive prices from the first page view.
      #
      # @return [Spree::Country, nil]
      def tax_country
        tax_address&.country || market&.default_country || store&.default_country
      end

      # The tax engine for this sale, chosen by its market. Falls back to the
      # store-wide default when the market names none, or when there is no
      # market yet (an empty cart before currency resolution).
      #
      # @return [Spree::TaxProvider::Base]
      def tax_provider
        market&.tax_provider_instance || Spree.default_tax_provider.new
      end

      # The typed inputs every +estimate+ call carries. Assembled here rather
      # than at each call site so a single-item re-estimate reaches the provider
      # with the same buyer registration and exemption evidence as a full
      # recalculation — the provider replaces the item's rows either way, so a
      # partial call missing them would silently re-tax an exempt line.
      #
      # @return [Hash]
      def tax_estimate_inputs
        {
          tax_date: Time.current,
          tax_identifier: resolved_tax_identifier,
          exemptions: Spree.tax_resolve_exemptions_service.new.call(order: self).value
        }
      end

      # The buyer's tax registration to compute against: a checkout-time
      # override first, then the customer's own. Nil means treat the sale as a
      # consumer sale, which is the legally safe default — charging normal tax
      # to an unidentified buyer is a presumption EU law explicitly protects.
      #
      # A completed order reads its own frozen snapshot instead of resolving
      # again, so its tax can still be explained after the customer edits or
      # withdraws the registration.
      #
      # Among a customer's registrations a verified one wins, then the most
      # recent — a plain fallback chain, which is why this is an overridable
      # method rather than a Dependencies seam.
      #
      # @return [Spree::TaxIdentifier, nil]
      def resolved_tax_identifier
        return tax_identifier if is_a?(Spree::Order) && completed?

        tax_identifier || customer_tax_identifier
      end

      def tax_total
        included_tax_total + additional_tax_total
      end

      # Sum of all line item amounts pre-tax
      def pre_tax_item_amount
        line_items.sum(:pre_tax_amount)
      end

      # Sum of all line item and fulfillment amounts pre-tax
      def pre_tax_total
        pre_tax_item_amount + fulfillments.sum(:pre_tax_amount)
      end

      private

      def customer_tax_identifier
        identifiers = customer&.tax_identifiers.to_a
        identifiers.find(&:verified?) || identifiers.max_by(&:created_at)
      end
    end
  end
end
