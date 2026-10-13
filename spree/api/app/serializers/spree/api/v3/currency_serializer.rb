module Spree
  module Api
    module V3
      class CurrencySerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize iso_code: [:string, enum: Spree::Money::Rounding::CURRENCY_CODES, enum_type_name: 'CurrencyCode'], name: [:string, deprecated: 'Name the currency from `iso_code` with `Intl.DisplayNames` (type `currency`). Removed in 6.1.'],
                 symbol: [:string, deprecated: 'Format amounts with `formatMoney` or `Intl.NumberFormat`, which place the symbol. Removed in 6.1.'],
                 decimal_places: :number

        attributes :iso_code, :name, :symbol

        # ISO 4217 minor units: the decimals every amount in this currency is
        # written with (2 for USD, 0 for JPY, 3 for KWD).
        attribute :decimal_places do |currency|
          Spree::Money::Rounding.precision(currency)
        end
      end
    end
  end
end
