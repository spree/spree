module Spree
  module Carts
    # Default cart-merge strategy (Spree::Dependencies.cart_merge_workflow) —
    # folds a guest cart into the signed-in customer's cart. Preserves the
    # legacy OrderMerger behavior minus its bugs: a currency-mismatched
    # source cart is surfaced (skipped and kept), never silently destroyed.
    #
    # In the workflow tier for its `validate` hook: merge policy is
    # store-specific (keep the larger cart, refuse to merge across channels,
    # cap the merged quantity) and previously required replacing the whole
    # strategy class.
    class Merge < Spree::Workflow
      hooks :validate, :after_items_moved, :after_merge

      # Every line item of the folded-in cart → the line item now holding its
      # quantity: itself when it moved across, or the surviving cart's line it
      # was added to. Set before +after_items_moved+ runs.
      #
      # @return [Hash{Spree::LineItem => Spree::LineItem}]
      attr_reader :line_item_map

      # @param cart [Spree::Cart] the surviving cart
      # @param other_cart [Spree::Cart, nil] the cart folded in and destroyed
      # @param customer [Object, nil] associated with the surviving cart when it
      #   has no customer yet
      def perform(cart:, other_cart: nil, customer: nil)
        super

        halt!(cart) if other_cart.nil? || other_cart.id == cart.id
        step :ensure_matching_currency

        # Veto point — before anything moves, so a rejection leaves both
        # carts untouched.
        run_hooks :validate

        ApplicationRecord.transaction do
          step :move_line_items
          # Inside the transaction and before the absorbed lines are deleted,
          # so an extension can move what it keeps against them.
          run_hooks :after_items_moved
          step :destroy_absorbed_line_items
          step :associate_customer
          step :destroy_drained_cart
        end

        step :recalculate_totals
        run_hooks :after_merge
        success(cart)
      end

      private

      def ensure_matching_currency
        return if other_cart.currency == cart.currency

        failure(cart, I18n.t('spree.errors.messages.cart_currency_mismatch'))
      end

      # A matching item absorbs the quantity; everything else is re-pointed
      # at the surviving cart. Absorbed items are deleted only after the
      # +after_items_moved+ hook.
      def move_line_items
        @line_item_map = other_cart.line_items.reload.to_a.index_with do |other_line_item|
          existing = matching_line_item(other_line_item)

          if existing
            existing.quantity += other_line_item.quantity
            existing.save!
            existing
          else
            other_line_item.update!(cart: cart, order: nil)
            other_line_item
          end
        end
        # Matching loaded the surviving cart's items before any moved in.
        cart.line_items.reset
      end

      def destroy_absorbed_line_items
        line_item_map.each do |other_line_item, line_item|
          other_line_item.destroy! unless other_line_item == line_item
        end
      end

      # Options-aware comparison (personalization, gift wrapping) with a
      # variant-only fallback when a custom comparer raises.
      def matching_line_item(other_line_item)
        cart.line_items.detect do |line_item|
          next false unless line_item.variant_id == other_line_item.variant_id
          next false if line_item.gift_card? && !line_item.same_gift_card_recipient?(other_line_item)

          begin
            Spree::Dependencies.cart_compare_line_items_service.constantize.call(
              order: cart, line_item: line_item, options: {}
            ).value
          rescue StandardError
            true
          end
        end
      end

      def associate_customer
        cart.associate_customer!(customer) if customer && cart.customer.blank?
      end

      def destroy_drained_cart
        other_cart.reload.destroy! if other_cart.line_items.reload.empty?
      end

      def recalculate_totals
        cart.recalculate_totals!
      end
    end
  end
end
