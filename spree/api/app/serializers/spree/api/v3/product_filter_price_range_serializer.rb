module Spree
  module Api
    module V3
      class ProductFilterPriceRangeSerializer < BaseSerializer
        typelize id: :string,
                 type: "'price_range'",
                 min: :string,
                 max: :string,
                 currency: :string

        attributes :id, :type

        # Search providers hand the bounds over as numbers.
        attribute(:min) { |range| Spree::Money::Rounding.format(range[:min], range[:currency], unit_price: true) }
        attribute(:max) { |range| Spree::Money::Rounding.format(range[:max], range[:currency], unit_price: true) }

        attributes :currency
      end
    end
  end
end
