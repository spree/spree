module Spree
  module Admin
    module Reports
      module Orders
        class AverageOrderValues < Base
          def initialize(params)
            @params = params
          end

          def call
            raise 'Date range is invalid.' unless range_missing?

            labels = create_report_labels

            orders = Spree::Order.complete
            orders = by_completed_at_min(orders)
            orders = by_completed_at_max(orders)
            orders = grouped_by(orders)
            values = orders.map { |date, results| [date, results.sum(&:total).to_f / results.size] }
                           .to_h

            labels.map { |label| [label, values[label] || 0] }
          end
        end
      end
    end
  end
end
