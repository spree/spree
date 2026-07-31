module Spree
  module Carts
    class Recalculate < Spree::Workflow
      # @param cart [Spree::Cart, Spree::Order] draft orders ride the same pipeline
      # @param line_item [Spree::LineItem, nil] the item whose change triggered this
      def perform(cart: nil, order: nil, line_item: nil, line_item_created: false, options: {})
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::Recalculate with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        super(cart: cart, line_item: line_item, line_item_created: line_item_created, options: options)

        step :unapply_stale_payment_sources
        step :refresh_totals
        step :rebuild_delivery_proposals
        step :activate_promotions
        # Typed rows (discounts + tax) are rebuilt by the full recalculation.
        step :final_recalculation, with: -> { Spree.cart_recalculate_totals_workflow }

        success(line_item)
      end

      private

      def unapply_stale_payment_sources
        cart.remove_gift_card if cart.gift_card.present?
        cart.payments.store_credits.checkout.destroy_all if cart.payments.store_credits.checkout.any?
      end

      # Totals must be current before the proposal rebuild — delivery rate
      # calculators (e.g. price sack) read them.
      def refresh_totals
        updater = cart.updater
        updater.update_item_count
        updater.update_totals
        updater.persist_totals
      end

      def rebuild_delivery_proposals
        cart.ensure_updated_fulfillments
      end

      def activate_promotions
        ::Spree::PromotionHandler::Cart.new(cart, line_item).activate
      end
    end
  end
end
