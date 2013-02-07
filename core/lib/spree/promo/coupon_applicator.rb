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
            result = { :coupon_applied? => true, :notice => I18n.t(:coupon_code_already_applied) }
          else
            event_name = "spree.checkout.coupon_code_added"

            promotion = Spree::Promotion.find_by_code(@order.coupon_code)

            if promotion.present?
              if promotion.expired?
                result = { :coupon_applied? => false, :error => I18n.t(:coupon_code_expired) }
              end

              if promotion.usage_limit_exceeded?
                result = { :coupon_applied? => false, :error => I18n.t(:coupon_code_max_usage) }
              end

              previous_promo = @order.adjustments.promotion.eligible.first
              ActiveSupport::Notifications.instrument(event_name, :coupon_code => @order.coupon_code, :order => @order)
              promo = @order.adjustments.promotion.detect { |p| p.originator.promotion.code == @order.coupon_code }
              if promo.present? and promo.eligible
                result = { :coupon_applied? => true, :success => I18n.t(:coupon_code_applied) }
              elsif previous_promo.present? and promo.present?
                result = { :coupon_applied? => false, :error => I18n.t(:coupon_code_better_exists) }
              elsif promo.present?
                result = { :coupon_applied? => false, :error => I18n.t(:coupon_code_not_eligible) }
              else
                # if the promotion was created after the order
                result = { :coupon_applied? => false, :error => I18n.t(:coupon_code_not_found) }
              end
            else
              result = { :coupon_applied? => false, :error => I18n.t(:coupon_code_not_found) }
            end
          end
        else
          result = { :coupon_applied? => true }
        end
        result
      end
    end
  end
end
