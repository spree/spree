module Spree
  module Admin
    module Reports
      class TotalSalesQuery
        def call
          Spree::Order.complete
                      .group_by { |order| order.completed_at.strftime('%Y-%m-%d') }
                      .map { |day, orders| [day, orders.sum(&:total)] }
        end
      end
    end
  end
end
