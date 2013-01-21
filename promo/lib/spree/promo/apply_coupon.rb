module Spree
  module Promo
    module ApplyCoupon
      def apply_coupon_code
        if @order.coupon_code.present?
          # check if coupon code is already applied
          if @order.adjustments.promotion.eligible.detect { |p| p.originator.promotion.code == @order.coupon_code }.present?
            return { :code_applied? => true, :notice => t(:coupon_code_already_applied) }
          else
            event_name = "spree.checkout.coupon_code_added"

            # TODO should restrict to payload's event name?
            promotion = Spree::Promotion.find_by_code(@order.coupon_code)

            if promotion.present?
              if promotion.expired?
                return { :code_applied? => false, :error => t(:coupon_code_expired) }
              end

              if promotion.usage_limit_exceeded?
                return { :code_applied? => false, :error => t(:coupon_code_max_usage) }
              end

              previous_promo = @order.adjustments.promotion.eligible.first
              ActiveSupport::Notifications.instrument(event_name, :coupon_code => @order.coupon_code, :order => @order)
              promo = @order.adjustments.promotion.detect { |p| p.originator.promotion.code == @order.coupon_code }
              if promo.present? and promo.eligible
                return { :code_applied? => true, :success => t(:coupon_code_applied) }
                true
              elsif previous_promo.present? and promo.present?
                return { :code_applied? => false, :error => t(:coupon_code_better_exists) }
              elsif promo.present?
                return { :code_applied? => false, :error => t(:coupon_code_not_eligible) }
              else
                # if the promotion was created after the order
                return { :code_applied? => false, :error => t(:coupon_code_not_found) }
              end
            else
              return { :code_applied? => false, :error => t(:coupon_code_not_found) }
            end
          end
        else
          true
        end
      end
    end
  end
end
