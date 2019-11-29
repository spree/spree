module Spree
  module Admin
    module Reports
      module TotalSales
        class JsonSerializer
          def call(objects)
            objects.map do |day, total_sales|
              { day: day, totalSales: total_sales }
            end
          end
        end
      end
    end
  end
end
