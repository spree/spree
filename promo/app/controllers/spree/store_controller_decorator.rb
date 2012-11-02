Spree::StoreController.class_eval do

  protected
    def apply_coupon_code
      if @order.coupon_code.present?
        # check if coupon code is already applied
        if @order.adjustments.promotion.eligible.detect { |p| p.originator.promotion.code == @order.coupon_code }.present?
          flash[:notice] = t(:coupon_code_already_applied)
          true
        else
          event_name = "spree.checkout.coupon_code_added"

          # TODO should restrict to payload's event name?
          # case insensitive coupon name
          promotion = Spree::Promotion.find(:first, :conditions => [ "lower(code) = ?", @order.coupon_code ])

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

            if promo.present? and promo.eligible
              flash[:success] = t(:coupon_code_applied)
              true
            elsif previous_promo.present? and promo.present?
              flash[:error] = t(:coupon_code_better_exists)
              false
            elsif promo.present?
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
