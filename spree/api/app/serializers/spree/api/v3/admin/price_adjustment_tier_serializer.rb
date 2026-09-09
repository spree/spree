module Spree
  module Api
    module V3
      module Admin
        # One band of a price list's percentage adjustment. Admin-only, like
        # the list itself — the storefront sees resolved prices, never the
        # arithmetic behind them.
        class PriceAdjustmentTierSerializer < V3::BaseSerializer
          typelize min_quantity: :number, percentage: :string

          attributes :min_quantity

          # A decimal as a string, like every other money-shaped value on the
          # wire — a float would round the merchant's own figure.
          attribute :percentage do |tier|
            tier.percentage&.to_s
          end
        end
      end
    end
  end
end
