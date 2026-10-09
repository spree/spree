module SpreeStripe
  # Stripe's integer amounts. Mostly the currency's ISO minor unit, with
  # Stripe's own exceptions (https://docs.stripe.com/currencies): its
  # zero-decimal currencies are sent in whole units, and ISK and UGX, zero-decimal
  # since, are still sent as two-decimal values ending in 00.
  module Units
    module_function

    ZERO_DECIMAL = %w[BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF VND VUV XAF XOF XPF].freeze
    WHOLE_IN_HUNDREDTHS = %w[ISK UGX].freeze

    # @param amount [BigDecimal, Spree::Money]
    # @param currency [String]
    # @return [Integer]
    def to_stripe(amount, currency)
      amount = amount.to_d if amount.respond_to?(:to_d)
      code = currency.to_s.upcase
      return Spree::Money::Rounding.quantize(amount, 0).to_i if ZERO_DECIMAL.include?(code)
      return Spree::Money::Rounding.quantize(amount, 0).to_i * 100 if WHOLE_IN_HUNDREDTHS.include?(code)

      Spree::Money::Rounding.to_minor_units(amount, code)
    end

    # @param units [Integer] as Stripe reports it
    # @param currency [String]
    # @return [BigDecimal]
    def from_stripe(units, currency)
      code = currency.to_s.upcase
      return BigDecimal(units) if ZERO_DECIMAL.include?(code)
      return BigDecimal(units) / 100 if WHOLE_IN_HUNDREDTHS.include?(code)

      Spree::Money::Rounding.from_minor_units(units, code)
    end
  end
end
