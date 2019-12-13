require 'csv'

module Spree
  module Admin
    module Reports
      module TotalCustomers
        class CsvSerializer
          def call(objects)
            CSV.generate do |csv|
              csv << ['date', 'total_customers']

              objects.each do |date, total_customers|
                csv << [date, total_customers]
              end
            end
          end
        end
      end
    end
  end
end
