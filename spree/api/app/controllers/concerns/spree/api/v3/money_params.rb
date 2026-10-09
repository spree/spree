module Spree
  module Api
    module V3
      # Money read from a request. The contract is a canonical decimal string
      # ("19.99"); a JSON number, a localized string or more decimals than the
      # currency has is answered with `invalid_money_format`, naming the field.
      module MoneyParams
        extend ActiveSupport::Concern

        included do
          rescue_from Spree::Money::InvalidFormat, with: :render_invalid_money_format
        end

        protected

        # @param name [Symbol] the request parameter
        # @param currency [String] the currency the amount is in
        # @param unit_price [Boolean] allows up to four decimals
        # @return [BigDecimal, nil] nil when the parameter is absent
        # @raise [Spree::Money::InvalidFormat]
        def money_param(name, currency, unit_price: false)
          value = params[name]
          # JSON numbers stay accepted until the 6.0 wire contract (money plan, PR B).
          value = value.to_s if value.is_a?(Integer) || value.is_a?(Float)
          Spree::Money::Rounding.parse_canonical(value, currency, unit_price: unit_price)
        rescue Spree::Money::InvalidFormat => error
          raise Spree::Money::InvalidFormat.new(error.message, field: name)
        end

        private

        def render_invalid_money_format(error)
          render_error(
            code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:invalid_money_format],
            message: [error.field, error.message].compact.join(' '),
            status: :unprocessable_content,
            details: error.field ? { error.field => [error.message] } : nil
          )
        end
      end
    end
  end
end
