module SpreeAdyen
  # Adyen's integer amounts, in the decimals Adyen publishes per currency
  # (https://docs.adyen.com/development-resources/currency-codes), which are
  # leading over ISO 4217: CLP and ISK take two decimals, CVE and IDR none. An
  # amount Adyen cannot represent raises, naming the rule, rather than being
  # rounded to a sum other than the one Spree records.
  module Amounts
    module_function

    ZERO_DECIMAL = %w[CVE DJF GNF IDR JPY KMF KRW PYG RWF UGX VND VUV XAF XOF XPF].freeze
    THREE_DECIMAL = %w[BHD IQD JOD KWD LYD OMR TND].freeze
    TWO_DECIMAL = %w[
      AED ALL AMD AOA ARS AUD AWG AZN BAM BBD BDT BMD BND BOB BRL BSD BWP BYN BZD CAD CHF CLP CNH CNY COP CRC
      CUP CZK DKK DOP DZD EGP ETB EUR FJD FKP GBP GEL GHS GIP GMD GTQ GYD HKD HNL HTG HUF ILS INR ISK JMD KES
      KGS KHR KYD KZT LAK LKR MAD MDL MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN NIO NOK NPR NZD PAB
      PEN PGK PHP PKR PLN QAR RON RSD RUB SAR SBD SCR SEK SGD SHP SLE SOS SRD STN SVC SZL THB TOP TRY TTD TWD
      TZS UAH USD UYU UZS VEF WST XCD XCG YER ZAR ZMW
    ].freeze

    class UnsupportedAmount < Spree::Core::GatewayError; end

    # @param currency [String]
    # @return [Boolean] whether Adyen takes the currency
    def supported?(currency)
      !decimals_for(currency).nil?
    end

    # @param amount [BigDecimal, Spree::Money]
    # @param currency [String]
    # @return [Integer] minor units as Adyen expects them
    # @raise [UnsupportedAmount] for a currency Adyen does not take, or an
    #   amount finer than its decimals
    def to_adyen(amount, currency)
      code = currency.to_s.upcase
      decimals = decimals_for!(code)
      amount = amount.to_d
      units = amount * (10**decimals)
      raise UnsupportedAmount, "Adyen takes #{code} with #{decimals} decimals, got #{amount.to_s('F')}" unless units.frac.zero?

      units.to_i
    end

    # @param units [Integer] as Adyen reports them
    # @param currency [String]
    # @return [BigDecimal]
    def from_adyen(units, currency)
      BigDecimal(units.to_s) / (10**decimals_for!(currency))
    end

    # The `amount` object Adyen's requests take.
    #
    # @return [Hash]
    def to_adyen_amount(amount, currency)
      { value: to_adyen(amount, currency), currency: currency.to_s.upcase }
    end

    def decimals_for!(currency)
      decimals_for(currency) || raise(UnsupportedAmount, "Adyen does not take #{currency.to_s.upcase}")
    end

    def decimals_for(currency)
      code = currency.to_s.upcase
      return 0 if ZERO_DECIMAL.include?(code)
      return 3 if THREE_DECIMAL.include?(code)

      2 if TWO_DECIMAL.include?(code)
    end
  end
end
