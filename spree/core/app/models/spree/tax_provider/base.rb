module Spree
  module TaxProvider
    # Contract for tax providers — the only sanctioned writers of
    # {Spree::TaxLine} rows. +estimate+ must use replace-all set semantics per
    # target item (delete the item's stale lines, insert fresh ones); that is
    # what keeps tax correct after address or item changes. Commit/void/refund
    # are lifecycle no-ops for providers without a remote ledger.
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
          default: name == Spree.default_tax_provider_class.to_s
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
      # @param order [Spree::Order]
      # @return [void]
      def commit(order); end

      # Reverses a committed tax document on cancellation.
      #
      # @param order [Spree::Order]
      # @return [void]
      def void(order); end

      # Reports a partial credit against the committed document, keyed to the
      # original transaction rather than voiding and re-committing it.
      #
      # @param order [Spree::Order]
      # @param return_items [Array<Spree::ReturnLineItem>] the returned lines
      # @param tax_date [Time, nil] the original supply date; nil = order.completed_at
      # @return [void]
      def refund(order, return_items, tax_date: nil); end
    end
  end
end
