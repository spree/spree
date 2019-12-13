module Spree
  module Admin
    module Reports
      module Orders
        class TotalSales < Base
          def initialize(params)
            @params = params
          end

          def call
            labels = create_report_labels

            orders = Spree::Order.complete
            orders = by_date_from(orders)
            orders = by_date_to(orders)
            orders = grouped_by(orders)
            values = orders.map { |day, results| [day, results.sum(&:total)] }.sort_by { |day, _| day }.to_h

            labels.map { |label| [label, (values[label] || BigDecimal(0)).round(2)] }
          end
        end
      end
    end
  end
end
