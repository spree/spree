module Spree
  module Carts
    class Recalculate < Spree::Workflow
      hooks :set_promotion_context, :after_recalculate

      # Promotion context contributed by set_promotion_context handlers,
      # readable by later hooks.
      attr_reader :promotion_context

      # @param cart [Spree::Cart, Spree::Order] draft orders ride the same pipeline
      # @param line_item [Spree::LineItem, nil] the item whose change triggered this
      def perform(cart: nil, order: nil, line_item: nil, line_item_created: false, options: {})
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::Recalculate with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        super(cart: cart, line_item: line_item, line_item_created: line_item_created, options: options)

        step :unapply_stale_payment_sources
        # Totals must be current before the proposal rebuild — delivery
        # rate calculators (e.g. price sack) read them.
        step :refresh_totals, with: -> { Spree.cart_recalculate_totals_workflow }
        step :rebuild_delivery_proposals
        step :activate_promotions
        # Typed rows (discounts + tax) are rebuilt by the full recalculation.
        step :final_recalculation, with: -> { Spree.cart_recalculate_totals_workflow }

        run_hooks :after_recalculate
        success(line_item)
      end

      private

      def unapply_stale_payment_sources
        cart.remove_gift_card if cart.gift_card.present?
        cart.payments.store_credits.checkout.destroy_all if cart.payments.store_credits.checkout.any?
      end

      def rebuild_delivery_proposals
        cart.ensure_updated_fulfillments
      end

      # Extensions contribute eligibility data (customer segment, campaign
      # attribution) before promotions are evaluated. Core's handler reads
      # the cart directly; the context is exposed for handlers and for a
      # promotion handler swapped in via Spree::Dependencies.
      def activate_promotions
        @promotion_context = run_hooks :set_promotion_context

        ::Spree::PromotionHandler::Cart.new(cart, line_item).activate
      end
    end
  end
end
