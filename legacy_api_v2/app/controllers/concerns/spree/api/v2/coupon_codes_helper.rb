module Spree
  module Api
    module V2
      module CouponCodesHelper
        def select_coupon_codes
          params[:coupon_code].present? ? [params[:coupon_code]] : check_coupon_codes
        end

        def check_coupon_codes
          spree_current_order.promotions.coupons.map(&:code)
        end

        def select_error(coupon_codes)
          result = coupon_handler.new(spree_current_order).remove(coupon_codes.first)
          result.error
        end

        def select_errors(coupon_codes)
          results = []
          coupon_codes.each do |coupon_code|
            results << coupon_handler.new(spree_current_order).remove(coupon_code)
          end

          results.select(&:error)
        end
      end
    end
  end
end
