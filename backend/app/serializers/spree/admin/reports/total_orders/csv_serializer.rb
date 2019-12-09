require 'csv'

module Spree
  module Admin
    module Reports
      module TotalOrders
        class CsvSerializer
          def call(objects)
            CSV.generate do |csv|
              csv << ['date', 'total_orders']

              objects.each do |date, total_orders|
                csv << [date, total_orders]
              end
            end
          end
        end
      end
    end
  end
end
