module Spree
  module Purchase
    # Tax location and pre-tax sums shared by Spree::Cart and Spree::Order.
    module Taxation
      # The address tax is computed against, honoring the store's
      # tax_using_ship_address preference.
      #
      # @return [Spree::Address, nil]
      def tax_address
        Spree::StorePreferences.read(store, :tax_using_ship_address) ? ship_address : bill_address
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
          exemptions: usable_exemptions
        }
      end

      # Everything a provider taxes when +estimate+ is called without an
      # explicit item list: line items, fulfillments and fees.
      #
      # Customs duties are deliberately absent. A duty is an import charge
      # levied by the destination's customs authority, not a supply that a
      # domestic sales tax or VAT applies to — taxing it here would both
      # invent tax the merchant never owed and double-count against the
      # import VAT a landed-cost provider writes itself, as a TaxLine against
      # the duty fee. Providers that do tax duties (import VAT is levied on
      # the duty in most regimes) pass their own item list.
      #
      # Each set is read through a fresh scope rather than the cached
      # association: recalculation runs after adjusters have just written
      # fees, and an association loaded earlier in the same request (empty at
      # order creation, typically) would leave those rows untaxed.
      #
      # @return [Array<Spree::LineItem, Spree::Fulfillment, Spree::Fee>]
      def taxable_items
        line_items.reload.to_a + fulfillments.reload.to_a + fees.where.not(kind: 'duty').to_a
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
      # A business customer's own registration outranks the buyer's, because the
      # invoice is addressed to the entity rather than the person who placed the
      # order. Among a customer's registrations a verified one wins, then the
      # most recent — a plain fallback chain, which is why this is an
      # overridable method rather than a Dependencies seam.
      #
      # @return [Spree::TaxIdentifier, nil]
      def resolved_tax_identifier
        return tax_identifier if is_a?(Spree::Order) && completed?

        tax_identifier || company_tax_identifier || customer_tax_identifier
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

      # The resolver is swappable, so what it returns is host code. An entry
      # whose per-line overrides cannot name their line is not a narrower claim
      # but a wider one — the provider would read it as the whole order being
      # exempt — so it is dropped rather than trusted. Charging tax is the safe
      # direction: under-exempting surfaces as a customer query, over-exempting
      # is tax the merchant owes and never collected.
      #
      # Public because a provider filing the sale needs the same evidence core
      # hands it as an +estimate+ argument: an external engine commits its
      # document after placement, and resolving again there could file an
      # exemption the estimate never applied.
      #
      # @return [Array]
      def usable_exemptions
        resolved = Array(Spree.tax_resolve_exemptions_service.new.call(order: self).value)

        resolved.select do |exemption|
          next true unless exemption.respond_to?(:valid?)
          next true if exemption.valid?

          Rails.error.report(
            Spree::Tax::UnusableExemptionError.new(
              "Discarded an unusable tax exemption: #{exemption.errors.full_messages.to_sentence}"
            ),
            handled: true,
            context: { order_id: id, reason_code: exemption.try(:reason_code) },
            source: 'spree.core'
          )
          false
        end
      end

      private

      # Read through the legal entity, never the node — a division holds no
      # registrations of its own.
      def company_tax_identifier
        best_of(company_legal_entity&.tax_identifiers)
      end

      def customer_tax_identifier
        best_of(customer&.tax_identifiers)
      end

      def best_of(identifiers)
        identifiers = identifiers.to_a
        identifiers.find(&:verified?) || identifiers.max_by(&:created_at)
      end
    end
  end
end
