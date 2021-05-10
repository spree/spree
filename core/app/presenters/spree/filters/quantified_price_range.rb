module Spree
  module Filters
    class QuantifiedPriceRange
      ALLOWED_QUANTIFIERS = [
        :less_than,
        :more_than
      ].freeze

      def initialize(price:, quantifier:)
        if ALLOWED_QUANTIFIERS.exclude?(quantifier.to_sym)
          raise ArgumentError, "quantifier must be one of: #{ALLOWED_QUANTIFIERS.join(', ')}"
        end

        @price = price
        @quantifier = quantifier.to_sym
      end

      def to_param
        case quantifier
        when :less_than
          less_than_param
        when :more_than
          more_than_param
        end
      end

      def to_s
        "#{I18n.t("activerecord.attributes.spree/product.#{quantifier}")} #{price}"
      end

      private

      attr_reader :price, :quantifier

      def less_than_param
        "0-#{price.to_i}"
      end

      def more_than_param
        "#{price.to_i}-Infinity"
      end
    end
  end
end
