module Spree
  module Fulfillments
    # Reads a delivery cost staff state. Shared by Spree::Fulfillments::Create
    # and ::Update so both refuse the same input: strictly, so "12 boxes" is
    # refused rather than truncated to 12, and within what the cost column
    # holds, so an oversized amount is refused rather than failing the write.
    module CostParsing
      extend ActiveSupport::Concern

      private

      def parse_cost(value)
        amount = BigDecimal(value.is_a?(String) ? value.strip : value.to_s)
        return amount if amount.finite? && !amount.negative? && fits_cost_column?(amount)

        failure(nil, Spree.t('fulfillments.errors.invalid_cost'))
      rescue ArgumentError
        failure(nil, Spree.t('fulfillments.errors.invalid_cost'))
      end

      def fits_cost_column?(amount)
        column = Spree::Fulfillment.columns_hash['cost']
        return true unless column.precision && column.scale

        amount.round(column.scale) < BigDecimal(10)**(column.precision - column.scale)
      end
    end
  end
end
