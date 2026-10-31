module SpreePaypalCheckout
  # PayPal's decimal-string amounts (https://developer.paypal.com/reference/currency-codes/).
  # Written in the currency's ISO exponent, except that PayPal takes HUF, JPY
  # and TWD only in whole units. An amount PayPal would refuse raises here,
  # naming the rule, rather than being rounded to a sum Spree did not record.
  module Amounts
    module_function

    SUPPORTED_CURRENCIES = %w[
      AUD BRL CAD CHF CNY CZK DKK EUR GBP HKD HUF ILS JPY MXN MYR NOK NZD PHP PLN SEK SGD THB TWD USD
    ].freeze
    WHOLE_UNITS = %w[HUF JPY TWD].freeze

    class UnsupportedAmount < Spree::Core::GatewayError; end

    # @param currency [String]
    # @return [Boolean]
    def supported_currency?(currency)
      SUPPORTED_CURRENCIES.include?(currency.to_s.upcase)
    end

    # @return [Boolean] whether PayPal takes this amount in this currency
    def payable?(amount, currency)
      to_paypal(amount, currency)
      true
    rescue UnsupportedAmount
      false
    end

    # @param amount [BigDecimal, Spree::Money]
    # @param currency [String]
    # @return [String] e.g. "19.99", or "2000" for yen
    # @raise [UnsupportedAmount] when PayPal would refuse the amount
    def to_paypal(amount, currency)
      amount = amount.to_d if amount.respond_to?(:to_d)
      code = currency.to_s.upcase
      raise UnsupportedAmount, "PayPal does not take #{code}" unless supported_currency?(code)

      places = WHOLE_UNITS.include?(code) ? 0 : Spree::Money::Rounding.precision(code)
      quantized = Spree::Money::Rounding.quantize(amount, places)
      if quantized != amount
        rule = places.zero? ? 'only in whole units' : "only to #{places} decimal places"
        raise UnsupportedAmount, "PayPal takes #{code} #{rule}, got #{amount.to_s('F')}"
      end
      return quantized.to_i.to_s if places.zero?

      Spree::Money::Rounding.format(quantized, code)
    end

    # @return [PaypalServerSdk::Money]
    def to_paypal_money(amount, currency)
      PaypalServerSdk::Money.new(currency_code: currency.to_s.upcase, value: to_paypal(amount, currency))
    end
  end
end
