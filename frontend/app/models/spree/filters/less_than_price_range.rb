module Spree
  module Filters
    class LessThanPriceRange
      def initialize(price:)
        @price = price
      end

      def to_param
        "0-#{price.to_i}"
      end

      def to_s
        "#{I18n.t('activerecord.attributes.spree/product.less_than')} #{price}"
      end

      private

      attr_reader :price
    end
  end
end
