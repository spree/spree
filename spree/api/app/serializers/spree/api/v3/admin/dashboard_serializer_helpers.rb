module Spree
  module Api
    module V3
      module Admin
        # Shared plumbing for the home dashboard payload builders
        # (analytics, rankings, operations).
        module DashboardSerializerHelpers
          private

          def money(amount)
            Spree::Money.new(amount, currency: currency).to_s
          end

          # Revenue = the persisted `pre_tax_amount` (discounted, net of
          # included taxes), so rankings reflect what was actually earned
          # after promotions and VAT instead of gross quantity * price.
          def revenue_sum_sql
            "SUM(#{Spree::LineItem.table_name}.pre_tax_amount)"
          end
        end
      end
    end
  end
end
