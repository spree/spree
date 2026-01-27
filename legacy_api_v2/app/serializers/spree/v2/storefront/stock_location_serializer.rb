module Spree
  module V2
    module Storefront
      class StockLocationSerializer < BaseSerializer
        set_type :stock_location

        attributes :name
      end
    end
  end
end
