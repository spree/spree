module Spree
  module PromotionHandler
    class Coupon
      attr_reader :order
      attr_accessor :error, :success

      def initialize(order)
        @order = order
      end

      def apply
        if order.coupon_code.present?
          if promotion.present? && promotion.actions.exists?
            handle_present_promotion(promotion)
          else
            if Promotion.with_coupon_code(order.coupon_code).try(:expired?)
              self.error = Spree.t(:coupon_code_expired)
            else
              self.error = Spree.t(:coupon_code_not_found)
            end
          end
        end

        self
      end

      def promotion
        @promotion ||= Promotion.active.includes(:promotion_rules, :promotion_actions).with_coupon_code(order.coupon_code)
      end

      def successful?
        success.present? && error.blank?
      end

      private

      def handle_present_promotion(promotion)
        return promotion_usage_limit_exceeded if promotion.usage_limit_exceeded?(order)
        return ineligible_for_this_order unless promotion.eligible?(order)

        # If any of the actions for the promotion return `true`,
        # then result here will also be `true`.
        result = promotion.activate(:order => order)
        if result
          determine_promotion_application_result(result)
        else
          self.error = Spree.t(:coupon_code_already_applied)
        end
      end

      def promotion_usage_limit_exceeded
        self.error = Spree.t(:coupon_code_max_usage)
      end

      def ineligible_for_this_order
        self.error = Spree.t(:coupon_code_not_eligible)
      end

      def determine_promotion_application_result(result)
        detector = lambda { |p| p.source.promotion.code.downcase == order.coupon_code.downcase }
        discount = order.line_item_adjustments.promotion.detect(&detector)
        discount ||= order.shipment_adjustments.promotion.detect(&detector)
        discount ||= order.adjustments.promotion.detect(&detector)

        if result and discount.eligible
          order.update_totals
          order.persist_totals
          self.success = Spree.t(:coupon_code_applied)
        else
          # if the promotion was created after the order
          self.error = Spree.t(:coupon_code_not_found)
        end
      end
    end
  end
end
