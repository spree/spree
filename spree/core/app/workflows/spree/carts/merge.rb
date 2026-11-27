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
        step :ensure_carts_unclaimed
        step :ensure_matching_currency

        # Veto point — before anything moves, so a rejection leaves both
        # carts untouched.
        run_hooks :validate

        ApplicationRecord.transaction do
          # Both rows stay locked until the merge commits, so a payment
          # session settling on either cart (PaymentSession#settle_payment!
          # runs under the owner's lock) waits for the merge or makes it
          # refuse — it cannot land between the check and the destroy.
          step :lock_unclaimed_carts
          step :move_line_items
          # Inside the transaction and before the absorbed lines are deleted,
          # so an extension can move what it keeps against them.
          run_hooks :after_items_moved
          step :destroy_absorbed_line_items
          step :associate_customer
          step :carry_custom_fields
          step :destroy_drained_cart
        end

        step :recalculate_totals
        run_hooks :after_merge
        success(cart)
      end

      private

      # Neither cart may change while a completion attempt holds it or a
      # gateway has taken money for it: merging would change the totals that
      # money was charged for. The folded-in cart is destroyed, so it must
      # also have no payment session the gateway may still settle — a
      # session can be captured while still +pending+ here, and destroying
      # it leaves the webhook nothing to record the payment against.
      #
      # A fast refusal before the validate hooks run; the answer that counts
      # is +lock_unclaimed_carts+, read under the row locks.
      def ensure_carts_unclaimed
        return unless [cart, other_cart].any?(&:completion_claimed?) || other_cart.payment_session_open?

        reject_claimed_carts
      end

      # Locks both carts in id order — the order every merge takes them in,
      # so two merges over the same pair cannot deadlock — and checks them
      # again from the locked rows. Uncached: the query cache could otherwise
      # answer with the unlocked read +ensure_carts_unclaimed+ made.
      def lock_unclaimed_carts
        held = Spree::Cart.uncached do
          locked = Spree::Cart.lock.where(id: [cart.id, other_cart.id]).order(:id).to_a
          # A cart deleted since the merge began is not one to fold either.
          locked.size < 2 || locked.any? { |locked_cart| claimed_or_unsafe_to_drain?(locked_cart) }
        end

        reject_claimed_carts if held
      end

      def claimed_or_unsafe_to_drain?(locked_cart)
        locked_cart.completed_at.present? || locked_cart.completion_claimed? ||
          (locked_cart.id == other_cart.id && locked_cart.payment_session_open?)
      end

      def reject_claimed_carts
        failure(cart, code: 'completion_in_progress', message: I18n.t('spree.cart_completion_in_progress'))
      end

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
          line_item.variant_id == other_line_item.variant_id &&
            Spree::Dependencies.cart_compare_line_items_service.constantize.call(
              order: cart, line_item: line_item, options: {}
            ).value
        rescue StandardError
          line_item.variant_id == other_line_item.variant_id
        end
      end

      def associate_customer
        cart.associate_customer!(customer) if customer && cart.customer.blank?
      end

      # What the shopper filled in on a cart about to be destroyed moves with
      # them, unless the surviving cart already answers the same field.
      def carry_custom_fields
        return unless other_cart.line_items.reload.empty?

        answered = cart.custom_fields.unscope(:includes).select(:custom_field_definition_id)
        other_cart.custom_fields.unscope(:includes).where.not(custom_field_definition_id: answered).
          update_all(resource_id: cart.id, updated_at: Time.current)
        cart.reset_custom_fields
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
