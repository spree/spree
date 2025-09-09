module Spree
  module Cart
    class Update
      prepend Spree::ServiceModule::Base

      def call(order:, params:)
        return failure(order) unless order.update(filter_order_items(order, params))

        line_items_creating_promotions = order.promotions.creating_line_items
        line_items_to_remove = order.line_items.where(quantity: 0)

        if line_items_to_remove.any? && line_items_creating_promotions.any?
          remove_line_items_promotions(order, line_items_creating_promotions, line_items_to_remove)
        end

        line_items_to_remove.each do |li|
          Spree::Dependencies.cart_remove_line_item_service.constantize.call(order: order, line_item: li)
        end

        # Update totals, then check if the order is eligible for any cart promotions.
        # If we do not update first, then the item total will be wrong and ItemTotal
        # promotion rules would not be triggered.
        ActiveRecord::Base.transaction do
          order.update_with_updater!
          ::Spree::PromotionHandler::Cart.new(order).activate
          order.ensure_updated_shipments
          order.payments.store_credits.checkout.destroy_all
          order.update_with_updater!
        end
        success(order)
      end

      private

      def filter_order_items(order, params)
        return params if params[:line_items_attributes].nil? || params[:line_items_attributes][:id]

        line_item_ids = order.line_item_ids.map(&:to_s)

        params[:line_items_attributes].each_pair do |id, value|
          params[:line_items_attributes].delete(id) unless line_item_ids.include?(value[:id].to_s) || value[:variant_id].present?
        end
        params
      end

      def remove_line_items_promotions(order, promotions, line_items)
        promotions.each do |promo|
          promo_line_items_variants_ids = line_items_creating_actions(promo).map { |action| action.promotion_action_line_items.pluck(:variant_id) }.flatten
          order.promotions = order.promotions - [promo] if (promo_line_items_variants_ids & line_items.pluck(:variant_id)).any?
        end
      end

      def line_items_creating_actions(promotion)
        promotion.actions.of_type('Spree::Promotion::Actions::CreateLineItems')
      end
    end
  end
end
