module Spree
  module Admin
    module Reports
      module TopProductsByUnitSold
        class JsonSerializer
          def call(objects)
            {
              labels: objects.map { |sku, _| sku },
              data: objects.map { |_, count| count }
            }
          end
        end
      end
    end
  end
end
