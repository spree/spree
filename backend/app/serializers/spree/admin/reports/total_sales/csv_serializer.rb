require 'csv'

module Spree
  module Admin
    module Reports
      module TotalSales
        class CsvSerializer
          def call(objects)
            CSV.generate do |csv|
              csv << ['date', 'total_sales']

              objects.each do |date, total_sales|
                csv << [date, total_sales]
              end
            end
          end
        end
      end
    end
  end
end
