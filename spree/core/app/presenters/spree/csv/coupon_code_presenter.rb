module Spree
  module CSV
    class CouponCodePresenter
      HEADERS = [
        'Code',
        'State',
        'Promotion Name',
        'Order Number',
        'Created At',
        'Updated At'
      ].freeze

      def initialize(coupon_code)
        @coupon_code = coupon_code
      end

      attr_accessor :coupon_code

      def call
        [
          coupon_code.display_code,
          coupon_code.state,
          coupon_code.promotion&.name,
          coupon_code.order&.number,
          coupon_code.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
          coupon_code.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
        ]
      end
    end
  end
end
