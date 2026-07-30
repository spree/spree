module Spree
  module Carts
    class Recalculate < Spree::Workflow
      argument :cart, [Spree::Cart, Spree::Order]
      argument :line_item, Spree::LineItem, default: nil
      argument :line_item_created, :boolean, default: false
      argument :options, default: {}
      alias_argument order: :cart, deprecated: true
      returns :line_item

      step :unapply_stale_payment_sources
      step :refresh_totals
      step :rebuild_delivery_proposals
      step :activate_promotions
      # Typed rows (discounts + tax) are rebuilt by the full recalculation.
      step :final_recalculation, with: -> { Spree::Carts::RecalculateTotals }

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
