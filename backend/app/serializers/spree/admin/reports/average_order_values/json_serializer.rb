module Spree
  module Admin
    module Reports
      module AverageOrderValues
        class JsonSerializer
          def call(objects)
            objects.map do |day, average_order_total|
              { day: day, averageOrderTotal: average_order_total }
            end
          end
        end
      end
    end
  end
end
