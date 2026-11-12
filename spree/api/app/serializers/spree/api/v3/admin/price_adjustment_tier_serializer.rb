module Spree
  module Api
    module V3
      module Admin
        # One band of a price list's percentage adjustment. Admin-only, like
        # the list itself — the storefront sees resolved prices, never the
        # arithmetic behind them.
        class PriceAdjustmentTierSerializer < V3::BaseSerializer
          typelize min_quantity: :number

          attributes :min_quantity

          rate_attributes :percentage
          typelize percentage: [:string, nullable: false]
        end
      end
    end
  end
end
