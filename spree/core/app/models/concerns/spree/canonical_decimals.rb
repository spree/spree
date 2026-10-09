module Spree
  # Decimal attributes written as a number or canonical decimal text
  # ("1234.56"). Text in any other shape raises Spree::Money::InvalidFormat,
  # which the API answers as `invalid_money_format`, instead of being read as
  # a wrong number the way Rails' cast reads "1,599.99" as 1 and "$10" as 0.
  module CanonicalDecimals
    extend ActiveSupport::Concern

    class_methods do
      # @param names [Array<Symbol>]
      # @param ignore_blank [Boolean] leave the attribute as it was when given a blank
      def canonical_decimals(*names, ignore_blank: false)
        names.each do |name|
          define_method("#{name}=") do |value|
            next if ignore_blank && value.blank?

            super(Spree::Money::Rounding.parse_decimal(value))
          rescue Spree::Money::InvalidFormat => error
            raise Spree::Money::InvalidFormat.new(error.message, field: name)
          end
        end
      end
    end
  end
end
