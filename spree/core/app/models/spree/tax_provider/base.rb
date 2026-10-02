module Spree
  module TaxProvider
    # Contract for tax providers — the only sanctioned writers of
    # {Spree::TaxLine} rows. +estimate+ must use replace-all set semantics per
    # target item (delete the item's stale lines, insert fresh ones); that is
    # what keeps tax correct after address or item changes, and the post-sale
    # +estimate_refund+ / +estimate_replacement+ follow the same rule.
    # Commit/void/refund/commit_replacement are lifecycle no-ops for providers
    # without a remote ledger.
    #
    # Providers are stateless and constructed without arguments, so anything
    # request-specific arrives as an argument rather than through the instance.
    class Base
      # Domains this provider cannot handle, so a merchant is warned when
      # pairing it with a market instead of silently under-collecting. Declared
      # on the class because core reads it while presenting the choice, before
      # any provider is instantiated.
      #
      # @return [Array<Symbol>]
      def self.unsupported_capabilities
        []
      end

      # Whether this provider can be selected for a store. External providers
      # override it to require a connected integration or credentials.
      #
      # @param store [Spree::Store]
      # @return [Boolean]
      def self.available_for_store?(_store)
        true
      end

      # The name a merchant sees when choosing an engine. Override in a provider
      # gem — a class name mangled into words rarely matches what the service is
      # actually called.
      #
      # @return [String]
      def self.display_name
        name.demodulize.titleize
      end

      # The declared limits with the strings a merchant can act on. A capability
      # with no translation degrades to its humanized key rather than a missing
      # translation, so an extension that declares one without shipping strings
      # still reads sensibly.
      #
      # @return [Array<Hash>]
      def self.unsupported_capability_details
        unsupported_capabilities.map do |capability|
          {
            key: capability.to_s,
            label: Spree.t("tax_capabilities.#{capability}.label", default: capability.to_s.humanize),
            description: Spree.t("tax_capabilities.#{capability}.description", default: nil)
          }.compact
        end
      end

      # How this engine describes itself to the admin, mirroring
      # Spree::PreferenceSchema#subclasses_with_preference_schema: the class
      # being described owns its own presentation, not the controller.
      #
      # @param store [Spree::Store]
      # @return [Hash]
      def self.to_api_hash(store)
        {
          id: name,
          name: display_name,
          available: available_for_store?(store),
          unsupported_capabilities: unsupported_capability_details,
          default: name == Spree.default_tax_provider.to_s
        }
      end

      # Recomputes tax for the given items and writes the TaxLine rows.
      # Replace-all set semantics per target item, and one row for every item
      # the provider formed a treatment for — zero-amount treatments included.
      # Never called on a completed order; the order-level money freeze gates it.
      #
      # @param owner [Spree::Cart, Spree::Order]
      # @param items [Array<Spree::LineItem, Spree::Fulfillment, Spree::Fee>, nil]
      #   nil = every taxable item on the owner
      # @param tax_date [Time, nil] date whose rates apply; nil = now
      # @param tax_identifier [Spree::TaxIdentifier, nil] resolved buyer
      #   registration, nil for a consumer sale
      # @param exemptions [Array] exemption evidence to apply
      # @param context [Hash] untyped provider extras from set_tax_line_context
      # @return [void] the written rows are the output; raise when the
      #   calculation cannot be completed
      def estimate(owner, items = nil, tax_date: nil, tax_identifier: nil, exemptions: [], context: {})
        raise NotImplementedError, "Please implement 'estimate' in your tax provider: #{self.class.name}"
      end

      # Finalizes tax with the provider when the order is placed. No-op for a
      # provider without a remote ledger — the rows are already the record.
      #
      # **Must be idempotent.** Completion is replayable: a crash between the
      # order commit and the cart stamp leaves `Carts::Complete` to re-run its
      # finalize phase, which calls this again for an order already committed.
      # Key the filing on the order and treat a duplicate as success, rather
      # than filing a second document for one sale.
      #
      # @param order [Spree::Order]
      # @return [void]
      def commit(order); end

      # Reverses a committed tax document on cancellation.
      #
      # @param order [Spree::Order]
      # @return [void]
      def void(order); end

      # The tax rate, as a fraction, on a service the platform itself supplies
      # and invoices — today only a marketplace's commission to a seller.
      #
      # Distinct from +estimate+ because nothing here is a sale: there is no
      # order, no buyer and no item, only a B2B supply between the platform and
      # a business it invoices. Returning a rate rather than writing rows is
      # deliberate for the same reason — the caller snapshots the number onto
      # its own ledger row, which is not a TaxLine.
      #
      # Providers that cannot price a service supply return nil rather than
      # zero: zero is the claim that the supply is untaxed, and the caller has
      # a configured default to fall back on that a wrong zero would silence.
      #
      # @param address [Spree::Address, nil] where the business being invoiced
      #   is established — for commission, the seller's billing address
      # @param store [Spree::Store]
      # @return [BigDecimal, nil] e.g. 0.21 for 21%; nil if it has no opinion
      def service_tax_rate(address:, store:)
        nil
      end

      # Works out the tax given back on lines of a return, claim or exchange,
      # and writes it as credit TaxLine rows on them. The customer is refunded
      # exactly what these rows hold, so this — not +refund+ — decides the
      # figure.
      #
      # Each item credits its +credited_quantity+, and zero means no rows.
      # Replace-all per item, as +estimate+: the rows are rewritten when the
      # warehouse counts what arrived and again when the money goes back.
      #
      # A provider may quote the credit, for example at the original
      # +tax_date+, or give back the recorded share of what the sale charged —
      # {Spree::TaxProvider::RecordedShare}, which Internal uses. Either way
      # it answers in the same rows.
      #
      # @param order [Spree::Order] a placed order
      # @param items [Array<Spree::ReturnLineItem, Spree::ClaimLineItem, Spree::ExchangeLineItem>]
      # @param amounts [Hash{Object => BigDecimal}, nil] the money refunded per
      #   item when it is less than the item's worth — a restocking fee, a
      #   part refund. Tax is then credited in the same proportion. Nil
      #   credits every item's full worth.
      # @param tax_date [Time, nil] the date whose rates apply; nil = order.completed_at
      # @return [void]
      # @raise [Spree::Tax::ProviderError] when the credit could not be worked out
      def estimate_refund(order, items, amounts: nil, tax_date: nil)
        raise NotImplementedError, "Please implement 'estimate_refund' in your tax provider: #{self.class.name}"
      end

      # Taxes the replacement an exchange sends out, as a new sale, and writes
      # it as charge TaxLine rows on the exchange lines. Never touches the
      # order's own rows, which stay as the sale was placed. Replace-all per
      # item; each item is taxed on its +taxable_basis+ under its
      # +tax_category_id+, and one whose +credited_quantity+ is zero ships
      # nothing and ends with no rows.
      #
      # @param order [Spree::Order] a placed order
      # @param items [Array<Spree::ExchangeLineItem>]
      # @param tax_date [Time, nil] date whose rates apply; nil = now
      # @param tax_identifier [Spree::TaxIdentifier, nil] the order's frozen registration
      # @param exemptions [Array] exemption evidence to apply
      # @return [void]
      # @raise [Spree::Tax::ProviderError] when the tax could not be worked out
      def estimate_replacement(order, items, tax_date: nil, tax_identifier: nil, exemptions: [])
        raise NotImplementedError, "Please implement 'estimate_replacement' in your tax provider: #{self.class.name}"
      end

      # Files an exchange's replacement as a sale. Called once the exchange is
      # fulfilled; must be idempotent, keyed on the exchange. No-op for a
      # provider without a remote ledger.
      #
      # @param order [Spree::Order]
      # @param items [Array<Spree::ExchangeLineItem>]
      # @return [void]
      def commit_replacement(order, items); end

      # Reports a partial credit against the committed document, keyed to the
      # original transaction rather than voiding and re-committing it. Called
      # after the money has moved.
      #
      # By then each item's credit rows hold what went back (see
      # +estimate_refund+), and a provider must credit no more than they do:
      # the customer was repaid that tax and no more. +amount+ is the money
      # refunded, which may be less than the items are worth when an admin kept
      # a restocking fee or refunded a goodwill figure of their own.
      #
      # @param order [Spree::Order]
      # @param return_items [Array<Spree::ReturnLineItem, Spree::ClaimLineItem, Spree::ExchangeLineItem>]
      # @param amount [BigDecimal, nil] the refund issued; nil = the lines' full worth
      # @param tax_date [Time, nil] the original supply date; nil = order.completed_at
      # @return [void]
      def refund(order, return_items, amount: nil, tax_date: nil); end
    end
  end
end
