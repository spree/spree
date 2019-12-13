module Spree
  module Admin
    module Reports
      module Orders
        class AverageOrderValues < Base
          def initialize(params)
            @params = params
          end

          def call
            labels = create_report_labels

            orders = Spree::Order.complete
            orders = by_date_from(orders)
            orders = by_date_to(orders)
            orders = grouped_by(orders)
            values = orders.map { |date, results| [date, BigDecimal(results.sum(&:total).to_f / results.size, 2)] }
                           .to_h

            labels.map { |label| [label, (values[label] || BigDecimal(0)).round(2)] }
          end
        end
      end
    end
  end
end
