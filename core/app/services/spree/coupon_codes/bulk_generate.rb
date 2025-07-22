module Spree
  module CouponCodes
    class BulkGenerate
      prepend Spree::ServiceModule::Base

      def call(promotion:, quantity: 10)
        coupon_codes = []

        Spree::CouponCode.transaction do
          quantity.times do
            coupon_codes << coupon_attributes(promotion).merge(code: create_code(promotion.code_prefix))
          end
          Spree::CouponCode.insert_all coupon_codes
        end

        success(promotion.reload.coupon_codes)
      end

      private

      def create_code(prefix = nil)
        loop do
          code = "#{prefix}#{SecureRandom.hex(8)}".downcase
          break code unless Spree::CouponCode.exists?(code: code)
        end
      end

      def coupon_attributes(promotion)
        {
          promotion_id: promotion.id,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end
  end
end
