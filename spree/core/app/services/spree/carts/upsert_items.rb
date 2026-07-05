module Spree
  module Carts
    # Bulk upsert line items on a cart.
    #
    # For each entry in +items+:
    # - If a line item for the variant already exists -> sets its quantity
    # - If no line item exists -> creates one with the given quantity
    #
    # After all items are processed the cart is recalculated once.
    #
    # @example
    #   Spree::Carts::UpsertItems.new.call(
    #     cart: cart,
    #     items: [
    #       { variant_id: "variant_k5nR8xLq", quantity: 2 },
    #       { variant_id: "variant_m3Rp9wXz", quantity: 1 }
    #     ]
    #   )
    #
    class UpsertItems
      prepend Spree::ServiceModule::Base

      def call(cart:, items:)
        items = Array(items)
        return success(cart) if items.empty?

        store = cart.store || Spree::Current.store

        ApplicationRecord.transaction do
          items.each do |item_params|
            item_params = item_params.to_h.deep_symbolize_keys
            variant = resolve_variant(store, item_params[:variant_id])
            next unless variant

            quantity = (item_params[:quantity] || 1).to_i

            return failure(variant, "#{variant.name} is not available in #{cart.currency}") if variant.amount_in(cart.currency).nil?

            line_item = Spree.line_item_by_variant_finder.new.execute(order: cart, variant: variant)

            if line_item
              line_item.quantity = quantity
              line_item.metadata = line_item.metadata.merge(item_params[:metadata].to_h) if item_params[:metadata].present?
            else
              line_item = cart.items.new(quantity: quantity, variant: variant, options: { currency: cart.currency })
              line_item.metadata = item_params[:metadata].to_h if item_params[:metadata].present?
            end

            return failure(line_item) unless line_item.save
          end

          cart.update_with_updater!
        end

        success(cart)
      end

      private

      def resolve_variant(store, variant_id)
        return nil if variant_id.blank?

        variant = store.variants.find_by_param(variant_id)

        raise ActiveRecord::RecordNotFound.new(
          "Variant '#{variant_id}' not found in this store",
          'Spree::Variant',
          'id',
          variant_id
        ) unless variant

        variant
      end
    end
  end
end
