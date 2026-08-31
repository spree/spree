module Spree
  module Catalogs
    # Writes the price list a catalog prices through, from an inline payload:
    # creates the owned list, updates the one already owned, or removes it
    # with nil (docs/plans/6.0-catalog-agreement-rework.md).
    #
    # Removal happens only on an explicit `price_list: null`, never as a side
    # effect of omitting the key.
    class SetPriceList < Spree::Workflow
      attr_reader :catalog

      # @param catalog [Spree::Catalog]
      # @param attributes [Hash, nil] list attributes, or nil to detach
      # @return [Spree::ServiceModule::Result] value is the catalog
      def perform(catalog:, attributes: nil)
        super

        step :write_price_list

        success(catalog)
      end

      private

      # Only an explicit nil removes the list. `{}` is a caller saying
      # "change nothing about the pricing", and destroying a list over that
      # would make an empty payload the most destructive one.
      def write_price_list
        return detach if attributes.nil?
        return if attributes.empty?

        existing = catalog.price_list
        return update_existing(existing) if existing

        create_owned
      end

      # Removes the list the catalog owns, rather than releasing it to
      # standalone matching: an owned list carries no rules, so released it
      # would price every shopper in the store. Soft-deleted, since the model
      # is paranoid.
      def detach
        return if catalog.price_list.nil?

        failure(catalog) unless catalog.price_list.destroy
      end

      def update_existing(price_list)
        result = Spree.price_list_update_workflow.call(
          price_list: price_list, attributes: list_attributes
        )
        failure(catalog, result.error.value) unless result.success?
      end

      # Born owned: the catalog id goes in with the create, since a percentage
      # is only valid on a list that has a catalog to scope it.
      def create_owned
        result = Spree.price_list_create_workflow.call(
          store: catalog.store,
          attributes: list_attributes(for_create: true).merge(catalog_id: catalog.id)
        )
        return failure(catalog, result.error.value) unless result.success?
        return failure(catalog) unless catalog.update(price_list: result.value)

        # The assortment usually exists before the pricing does — a merchant
        # picks products, then decides what they cost. The new list starts
        # from what the catalog already holds, so the spreadsheet has rows
        # to edit rather than opening empty.
        result.value.add_products(catalog.catalog_products.pluck(:product_id))
      end

      # A list a catalog owns is reached only through that catalog, so it
      # needs no name of its own to be found by — but the column is required,
      # and a merchant who never sees the list should not have to name it.
      #
      # It is also born active rather than draft: the catalog's own `active`
      # flag already decides whether the agreement applies, and a second
      # dormant switch inside it would only be a way to configure pricing
      # that silently does nothing.
      def list_attributes(for_create: false)
        attrs = attributes.to_h.with_indifferent_access
        attrs[:name] = catalog.name if attrs[:name].blank?
        attrs[:status] = 'active' if for_create && attrs[:status].blank?
        attrs[:rules] = merged_rules(attrs[:rules]) if attrs.key?(:rules)
        attrs
      end

      # This payload speaks only for the list's contextual rules — a catalog
      # states the terms of the purchase, while who the agreement is for is
      # settled by its assignments. Rules are reconciled by replacement, so
      # the audience rules the caller never mentioned are merged back in;
      # without this, editing a catalog's name through the inline payload
      # would destroy a market rule and silently change how its prices are
      # restated for VAT.
      def merged_rules(rows)
        existing = catalog.price_list&.price_rules&.to_a || []
        untouched = existing.reject(&:contextual?)

        contextual = Array(rows).filter_map do |row|
          attrs = row.to_h.with_indifferent_access
          klass = Spree::PriceRule.find_by_api_type(attrs[:type])
          next unless klass&.contextual?

          # A rule is unique per kind on a list, and this payload names kinds
          # rather than rows, so an id the caller did not send is filled in
          # from the row already holding that kind. Without it every save
          # would try to create a second rule of the same type and be
          # refused by the uniqueness validation.
          attrs[:id] ||= existing.find { |rule| rule.class == klass }&.id
          attrs
        end

        contextual + untouched.map { |rule| { id: rule.id, type: rule.class.api_type, preferences: rule.preferences } }
      end
    end
  end
end
