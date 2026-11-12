module SpreeStripe
  # Stripe's integer amounts. Mostly the currency's ISO minor unit, with
  # Stripe's own exceptions (https://docs.stripe.com/currencies): its
  # zero-decimal currencies are sent in whole units, and ISK and UGX, zero-decimal
  # since, are still sent as two-decimal values ending in 00. Stripe also takes
  # three-decimal currencies only in steps of 0.010, and pays out HUF and TWD
  # only in whole units; an amount it would refuse raises here, naming the rule,
  # rather than being rounded to a sum other than the one Spree records.
  module Units
    module_function

    ZERO_DECIMAL = %w[BIF CLP DJF GNF JPY KMF KRW MGA PYG RWF VND VUV XAF XOF XPF].freeze
    WHOLE_IN_HUNDREDTHS = %w[ISK UGX].freeze
    THREE_DECIMAL = %w[BHD JOD KWD OMR TND].freeze
    WHOLE_PAYOUTS = %w[HUF TWD].freeze

    class UnsupportedAmount < Spree::Core::GatewayError; end

    # @param amount [BigDecimal, Spree::Money]
    # @param currency [String]
    # @param payout [Boolean] a payout or transfer rather than a charge
    # @return [Integer]
    # @raise [UnsupportedAmount] when Stripe would refuse the amount
    def to_stripe(amount, currency, payout: false)
      amount = amount.to_d if amount.respond_to?(:to_d)
      code = currency.to_s.upcase
      return Spree::Money::Rounding.quantize(amount, 0).to_i if ZERO_DECIMAL.include?(code)
      return Spree::Money::Rounding.quantize(amount, 0).to_i * 100 if WHOLE_IN_HUNDREDTHS.include?(code)

      units = Spree::Money::Rounding.to_minor_units(amount, code)
      if THREE_DECIMAL.include?(code) && (units % 10).nonzero?
        raise UnsupportedAmount, "Stripe takes #{code} only in steps of 0.010, got #{amount.to_s('F')}"
      end
      if payout && WHOLE_PAYOUTS.include?(code) && (units % 100).nonzero?
        raise UnsupportedAmount, "Stripe pays out #{code} only in whole units, got #{amount.to_s('F')}"
      end

      units
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
