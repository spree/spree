module Spree
  module Api
    module V3
      class ProductFilterPriceRangeSerializer < BaseSerializer
        typelize id: :string,
                 type: "'price_range'",
                 min: :number,
                 max: :number,
                 currency: :string

        attributes :id, :type, :min, :max, :currency
      end
    end
  end
end
