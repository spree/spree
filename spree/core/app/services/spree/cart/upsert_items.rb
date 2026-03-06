module Spree
  module Cart
    # Bulk upsert line items on an order.
    #
    # For each entry in +line_items+:
    # - If a line item for the variant already exists → sets its quantity
    # - If no line item exists → creates one with the given quantity
    #
    # After all items are processed the order is recalculated once.
    #
    # Price calculation and tax adjustments are handled by LineItem model callbacks
    # (copy_price, update_adjustments, update_tax_charge), so we only need to
    # save each item and run a single order recalculation at the end.
    #
    # @example
    #   Spree::Cart::UpsertItems.call(
    #     order: order,
    #     line_items: [
    #       { variant_id: "variant_k5nR8xLq", quantity: 2 },
    #       { variant_id: "variant_m3Rp9wXz", quantity: 1 }
    #     ]
    #   )
    #
    class UpsertItems
      prepend Spree::ServiceModule::Base

      def call(order:, line_items:)
        line_items = Array(line_items)
        return success(order) if line_items.empty?

        store = order.store || Spree::Current.store

        ApplicationRecord.transaction do
          line_items.each do |item_params|
            item_params = item_params.to_h.deep_symbolize_keys
            variant = resolve_variant(store, item_params[:variant_id])
            next unless variant

            quantity = (item_params[:quantity] || 1).to_i

            return failure(variant, "#{variant.name} is not available in #{order.currency}") if variant.amount_in(order.currency).nil?

            line_item = Spree.line_item_by_variant_finder.new.execute(order: order, variant: variant)

            if line_item
              line_item.quantity = quantity
              line_item.metadata = line_item.metadata.merge(item_params[:metadata].to_h) if item_params[:metadata].present?
            else
              line_item = order.line_items.new(quantity: quantity, variant: variant, options: { currency: order.currency })
              line_item.metadata = item_params[:metadata].to_h if item_params[:metadata].present?
            end

            return failure(line_item) unless line_item.save
          end

          order.update_with_updater!
        end

        success(order)
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
