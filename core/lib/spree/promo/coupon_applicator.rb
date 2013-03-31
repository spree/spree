module Spree
  module Promo
    class CouponApplicator
      attr_reader :order

      def initialize(order)
        @order = order
      end

      def apply
        if @order.coupon_code.present?
          # check if coupon code is already applied
          if @order.adjustments.promotion.eligible.detect { |p| p.originator.promotion.code == @order.coupon_code }.present?
            return { :coupon_applied? => true, :notice => I18n.t(:coupon_code_already_applied) }
          else
            promotion = Spree::Promotion.find_by_code(@order.coupon_code)
            if promotion.present?
              handle_present_promotion(promotion)
            else
              return { :coupon_applied? => false, :error => I18n.t(:coupon_code_not_found) }
            end
          end
        else
          return { :coupon_applied? => true }
        end
      end

      private

      def handle_present_promotion(promotion)
        promotion_expired if promotion.expired?
        promotion_usage_limit_exceeded if promotion.usage_limit_exceeded?

        previous_promo = @order.adjustments.promotion.eligible.first
        event_name = "spree.checkout.coupon_code_added"
        ActiveSupport::Notifications.instrument(event_name, :coupon_code => @order.coupon_code, :order => @order)
        promo = @order.adjustments.promotion.detect { |p| p.originator.promotion.code == @order.coupon_code }
        determine_promotion_application_result(promo)
      end

      def promotion_expired
        return { :coupon_applied? => false, :error => I18n.t(:coupon_code_expired) }
      end

      def promotion_usage_limit_exceeded
        return { :coupon_applied? => false, :error => I18n.t(:coupon_code_max_usage) }
      end

      def determine_promotion_application_result(promo)
        if promo.present? and promo.eligible
          return { :coupon_applied? => true, :success => I18n.t(:coupon_code_applied) }
        elsif previous_promo.present? and promo.present?
          return { :coupon_applied? => false, :error => I18n.t(:coupon_code_better_exists) }
        elsif promo.present?
          return { :coupon_applied? => false, :error => I18n.t(:coupon_code_not_eligible) }
        else
          # if the promotion was created after the order
          return { :coupon_applied? => false, :error => I18n.t(:coupon_code_not_found) }
        end
      end
    end
  end
end
