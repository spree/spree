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

    # The largest amount Stripe will take that is not more than `units`:
    # rounded down to the step the currency moves in (0.010 for three-decimal
    # currencies, whole units for ISK and UGX, and for HUF and TWD payouts).
    # For figures Spree computes rather than records, such as a share of a
    # converted charge, where rounding down is the safe direction.
    #
    # @param units [Integer] minor units as Stripe counts them
    # @param currency [String]
    # @param payout [Boolean] a payout or transfer rather than a charge
    # @return [Integer]
    def floor_to_step(units, currency, payout: false)
      code = currency.to_s.upcase
      step = if THREE_DECIMAL.include?(code) then 10
             elsif WHOLE_IN_HUNDREDTHS.include?(code) || (payout && WHOLE_PAYOUTS.include?(code)) then 100
             else 1
             end
      units.to_i - (units.to_i % step)
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
