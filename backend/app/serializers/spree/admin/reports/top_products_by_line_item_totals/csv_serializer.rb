require 'csv'

module Spree
  module Admin
    module Reports
      module TopProductsByLineItemTotals
        class CsvSerializer
          def call(objects)
            CSV.generate do |csv|
              csv << %w[sku line_item_totals]

              objects.each do |sku, line_item_totals|
                csv << [sku, line_item_totals]
              end
            end
          end
        end
      end
    end
  end
end
