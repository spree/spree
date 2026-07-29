module Spree
  module Carts
    # Default cart-merge strategy (Spree::Dependencies.cart_merge_strategy).
    # Preserves the legacy OrderMerger behavior minus its bugs: a
    # currency-mismatched source cart is surfaced (skipped and kept), never
    # silently destroyed.
    class Merge
      prepend Spree::ServiceModule::Base

      def call(cart:, other_cart:, user: nil)
        return success(cart) if other_cart.nil? || other_cart.id == cart.id
        return failure(cart, Spree.t('errors.messages.cart_currency_mismatch')) if other_cart.currency != cart.currency

        ApplicationRecord.transaction do
          other_cart.line_items.reload.each do |other_line_item|
            current = cart.line_items.detect do |line_item|
              line_item.variant_id == other_line_item.variant_id &&
                Spree::Dependencies.cart_compare_line_items_service.constantize.call(order: cart, line_item: line_item, options: {}).value
            rescue StandardError
              line_item.variant_id == other_line_item.variant_id
            end

            if current
              current.quantity += other_line_item.quantity
              current.save!
              other_line_item.destroy!
            else
              other_line_item.update!(cart: cart, order: nil)
            end
          end

          cart.associate_user!(user) if user && cart.customer.blank?
          other_cart.reload.destroy! if other_cart.line_items.reload.empty?
        end

        cart.update_with_updater!
        success(cart)
      end
    end
  end
end
