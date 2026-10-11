module Spree
  module Api
    module V3
      class CurrencySerializer
        include Alba::Resource
        include Typelizer::DSL

        typelize iso_code: :string, name: :string, symbol: :string, decimal_places: :number

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
