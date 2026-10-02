module Spree
  module CouponCodes
    class BulkGenerate
      prepend Spree::ServiceModule::Base

      def call(promotion:, quantity: 10)
        Spree::CouponCode.transaction do
          Spree::CouponCode.insert_all(
            Array.new(quantity) { { promotion_id: promotion.id, code: create_code(promotion.code_prefix) } }
          )
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
    end
  end
end
