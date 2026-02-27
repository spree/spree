module Spree
  module PromotionHandler
    class Coupon
      attr_reader :order, :store, :options
      attr_accessor :error, :success, :status_code

      def initialize(order, options = {})
        @order = order
        @store = order.store
        @options = options
      end

      def apply
        if load_gift_card_code

          if @gift_card.expired?
            set_error_code :gift_card_expired
            return self
          elsif @gift_card.redeemed?
            set_error_code :gift_card_already_redeemed
            return self
          end

          result = order.apply_gift_card(@gift_card)

          if result.success?
            set_success_code(:gift_card_applied)
          else
            set_error_code(result.value, result.error.value || {})
          end

          return self
        end

        if order.coupon_code.present?
          if promotion.present? && promotion.actions.exists?
            handle_present_promotion
          elsif store.promotions.with_coupon_code(order.coupon_code).try(:expired?)
            set_error_code :coupon_code_expired
          else
            set_error_code :coupon_code_not_found
          end
        else
          set_error_code :coupon_code_not_found
        end
        self
      end

      def remove(coupon_code)
        if order.gift_card
          result = order.remove_gift_card

          if result.success?
            set_success_code(:gift_card_removed)
          else
            set_error_code(result.value)
          end

          return self
        end

        promotion = order.promotions.with_coupon_code(coupon_code)
        if promotion.present?
          # Order promotion has to be destroyed before line item removing
          order.promotions.delete(promotion)

          if promotion.multi_codes?
            coupon_code = promotion.coupon_codes.find_by(order: order)
            coupon_code&.remove_from_order
          else
            promotion.touch
          end

          remove_promotion_adjustments(promotion)
          remove_promotion_line_items(promotion)
          order.update_with_updater!

          set_success_code :adjustments_deleted
        else
          set_error_code :coupon_code_not_found
        end
        self
      end

      def set_success_code(code)
        @status_code = code
        @success = Spree.t(code)
      end

      def set_error_code(code, locale_options = {})
        @status_code = code
        @error = Spree.t(code, locale_options)
      end

      # Returns the promotion for the order
      #
      # @return [Spree::Promotion]
      def promotion
        @promotion ||= store.promotions.active.includes(
          :promotion_rules, :promotion_actions
        ).with_coupon_code(order.coupon_code)
      end

      # Returns the amount of adjustments for the promotion
      #
      # @return [Numeric]
      def adjustments_amount
        @adjustments_amount ||=
          @order.all_adjustments.promotion.eligible.
          where(source: promotion&.actions).
          sum(:amount)
      end

      # Returns true if the code was applied successfully
      #
      # @return [Boolean]
      def successful?
        success.present? && error.blank?
      end

      private

      def remove_promotion_adjustments(promotion)
        promotion_actions_ids = promotion.actions.pluck(:id)
        order.all_adjustments.where(source_id: promotion_actions_ids,
                                    source_type: 'Spree::PromotionAction').destroy_all
      end

      def remove_promotion_line_items(promotion)
        create_line_item_actions_ids = promotion.actions.where(type: 'Spree::Promotion::Actions::CreateLineItems').pluck(:id)

        Spree::PromotionActionLineItem.where(promotion_action: create_line_item_actions_ids).find_each do |item|
          line_item = order.find_line_item_by_variant(item.variant)
          next if line_item.blank?

          Spree.cart_remove_item_service.call(order: order, variant: item.variant, quantity: item.quantity)
        end
      end

      def handle_present_promotion
        return promotion_applied if promotion_exists_on_order?
        return set_error_code :coupon_code_used if promotion.coupon_codes.used.where(code: order.coupon_code).exists?
        return promotion_usage_limit_exceeded if promotion.usage_limit_exceeded?(order)

        unless promotion.eligible?(order, options)
          self.error = promotion.eligibility_errors.full_messages.first unless promotion.eligibility_errors.blank?
          return (error || ineligible_for_this_order)
        end

        # If any of the actions for the promotion return `true`,
        # then result here will also be `true`.
        if promotion.activate(order: order)
          determine_promotion_application_result
        else
          set_error_code :coupon_code_unknown_error
        end
      end

      def promotion_usage_limit_exceeded
        set_error_code :coupon_code_max_usage
      end

      def ineligible_for_this_order
        set_error_code :coupon_code_not_eligible
      end

      def promotion_applied
        set_error_code :coupon_code_already_applied
      end

      def promotion_exists_on_order?
        order.promotions.include? promotion
      end

      def determine_promotion_application_result
        coupon_code = order.coupon_code.downcase

        # Check for applied adjustments.
        discount = order.all_adjustments.promotion.eligible.detect do |p|
          p.source.promotion.code.try(:downcase) == coupon_code ||
            Spree::CouponCode.unused.where(promotion_id: p.source.promotion_id, code: coupon_code).exists?
        end

        # Check for applied line items.
        created_line_items = promotion.actions.detect do |a|
          Object.const_get(a.type).ancestors.include?(
            Spree::Promotion::Actions::CreateLineItems
          )
        end

        if discount || created_line_items
          handle_coupon_code(discount, coupon_code) if discount

          order.update_with_updater!
          set_success_code :coupon_code_applied
        elsif order.promotions.with_coupon_code(order.coupon_code)
          # since CouponCode is disposable...
          if Spree::CouponCode.used?(order.coupon_code)
            set_error_code :coupon_code_max_usage
          else
            # if the promotion exists on an order, but wasn't found above,
            # we've already selected a better promotion
            set_error_code :coupon_code_better_exists
          end
        else
          # if the promotion was created after the order
          set_error_code :coupon_code_not_found
        end
      end

      def handle_coupon_code(discount, coupon_code)
        Spree::CouponCode.unused.find_by(promotion_id: discount.source.promotion_id, code: coupon_code)&.apply_order!(order)
      end

      def load_gift_card_code
        return unless order.coupon_code.present?

        @gift_card = order.store.gift_cards.find_by(code: order.coupon_code.downcase)
      end
    end
  end
end
