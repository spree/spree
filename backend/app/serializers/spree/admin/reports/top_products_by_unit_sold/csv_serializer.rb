require 'csv'

module Spree
  module Admin
    module Reports
      module TopProductsByUnitSold
        class CsvSerializer
          def call(objects)
            CSV.generate do |csv|
              csv << %w[sku number_of_products_sold]

              objects.each do |sku, number_of_products_sold|
                csv << [sku, number_of_products_sold]
              end
            end
          end
        end
      end
    end
  end
end
