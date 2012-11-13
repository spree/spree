module Spree
  class StoreController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order

    def unauthorized
      render 'spree/shared/unauthorized', :layout => Spree::Config[:layout], :status => 401
    end

    protected
      # This method is placed here so that the CheckoutController 
      # and OrdersController can both reference it.
      def apply_coupon_code
        if @order.coupon_code.present?
          # check if coupon code is already applied
          if @order.adjustments.promotion.eligible.detect { |p| p.originator.promotion.code == @order.coupon_code }.present?
            flash[:notice] = t(:coupon_code_already_applied)
            true
          else
            event_name = "spree.checkout.coupon_code_added"
            promotion = Spree::Promotion.where("event_name = ? AND lower(code) = ?", event_name, @order.coupon_code).first

            if promotion.present?
              if promotion.expired?
                flash[:error] = t(:coupon_code_expired)
                return false
              end

              if promotion.usage_limit_exceeded?
                flash[:error] = t(:coupon_code_max_usage)
                return false
              end

              previous_promo = @order.adjustments.promotion.eligible.first
              fire_event(event_name, :coupon_code => @order.coupon_code)
              promo = @order.adjustments.promotion.detect { |p| p.originator.promotion.code == @order.coupon_code }

              if promo.present? and promo.eligible?
                flash[:success] = t(:coupon_code_applied)
                true
              elsif promo.present?
                flash[:error] = t(:coupon_code_not_eligible)
                false
              elsif previous_promo.present?
                flash[:error] = t(:coupon_code_better_exists)
                false
              else
                # if the promotion was created after the order
                flash[:error] = t(:coupon_code_not_found)
                false
              end
            else
              flash[:error] = t(:coupon_code_not_found)
              false
            end
          end
        else
          true
        end
      end
  end
end

