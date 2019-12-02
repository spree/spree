require 'csv'

module Spree
  module Admin
    module Reports
      module AverageOrderValues
        class CsvSerializer
          def call(objects)
            CSV.generate do |csv|
              csv << ['date', 'average_order_values']

              objects.each do |date, average_order_values|
                csv << [date, average_order_values]
              end
            end
          end
        end
      end
    end
  end
end
