module Spree
  module Filters
    class MoreThanPriceRange
      def initialize(price:)
        @price = price
      end

      def to_param
        "#{price.to_i}-0"
      end

      def to_s
        "#{I18n.t('activerecord.attributes.spree/product.more_than')} #{price}"
      end

      private

      attr_reader :price
    end
  end
end
