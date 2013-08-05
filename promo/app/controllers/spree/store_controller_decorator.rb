Spree::StoreController.class_eval do

  protected
    def apply_coupon_code
      if @order.coupon_code.present?
        # check if coupon code is already applied
        if @order.coupon_code_applied?
          flash[:notice] = t(:coupon_code_already_applied)
          true
        else
          event_name = "spree.checkout.coupon_code_added"

          # TODO should restrict to payload's event name?
          current_promotion = @order.find_promo_for_coupon_code

          if current_promotion.present?
            if current_promotion.expired?
              flash[:error] = t(:coupon_code_expired)
              return false
            end

            if current_promotion.usage_limit_exceeded?
              flash[:error] = t(:coupon_code_max_usage)
              return false
            end

            previous_promo = @order.adjustments.promotion.eligible.first
            current_promotion.activate(:order => @order, :coupon_code => @order.coupon_code)
            promo_adjustment = @order.find_adjustment_for_coupon_code

            if promo_adjustment.present? and promo_adjustment.eligible
              flash[:success] = t(:coupon_code_applied)
              true
            elsif previous_promo.present? and promo_adjustment.present?
              flash[:error] = t(:coupon_code_better_exists)
              false
            elsif promo_adjustment.present?
              flash[:error] = t(:coupon_code_not_eligible)
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
