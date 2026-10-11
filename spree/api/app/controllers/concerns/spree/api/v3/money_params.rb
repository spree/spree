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
        # @param allow_number [Boolean] also reads a JSON number, for a Store
        #   API field clients already send as one. It is read through its
        #   decimal text, never as a float, so `12.5` is exactly 12.50.
        # @return [BigDecimal, nil] nil when the parameter is absent
        # @raise [Spree::Money::InvalidFormat]
        def money_param(name, currency, unit_price: false, allow_number: false)
          value = params[name]
          value = value.to_s if allow_number && value.is_a?(Numeric)
          Spree::Money::Rounding.parse_canonical(value, currency, unit_price: unit_price)
        rescue Spree::Money::InvalidFormat => error
          raise Spree::Money::InvalidFormat.new(error.message, field: name)
        end

        # A rate or other plain decimal: any number of decimals, but still a
        # canonical decimal string.
        #
        # @param name [Symbol] the request parameter
        # @return [BigDecimal, nil] nil when the parameter is absent
        # @raise [Spree::Money::InvalidFormat]
        def decimal_param(name)
          Spree::Money::Rounding.parse_canonical_decimal(params[name])
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
