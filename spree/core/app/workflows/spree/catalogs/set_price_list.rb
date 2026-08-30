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

      def write_price_list
        return detach if attributes.blank?

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

      def create_owned
        result = Spree.price_list_create_workflow.call(
          store: catalog.store, attributes: list_attributes(for_create: true)
        )
        return failure(catalog, result.error.value) unless result.success?

        failure(catalog) unless catalog.update(price_list: result.value)
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
        attrs
      end
    end
  end
end
