module Spree
  module Orders
    # Bulk upsert line items on an order. Mirrors Spree::Carts::UpsertItems
    # but is admin/order-side (separate from the cart pipeline per the 6.0
    # cart/order split — see docs/plans/6.0-cart-order-split.md).
    #
    # For each entry in +items+:
    # - If a line item for the variant already exists -> sets its quantity
    # - If no line item exists -> creates one with the given quantity
    #
    # Order totals are NOT recalculated here. Callers (Spree::Orders::Create
    # and Spree::Orders::Update) are responsible for running shipment
    # rebuilding and a final `order.update_with_updater!` once their
    # full pipeline (items, shipments, coupons) has run.
    class UpsertItems
      prepend Spree::ServiceModule::Base

      def call(order:, items:)
        items = Array(items)
        return success(order) if items.empty?

        store = order.store || Spree::Current.store

        ApplicationRecord.transaction do
          items.each do |item_params|
            item_params = item_params.to_h.deep_symbolize_keys
            variant = resolve_variant(store, item_params[:variant_id])
            next unless variant

            quantity = (item_params[:quantity] || 1).to_i
            next if quantity <= 0

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
