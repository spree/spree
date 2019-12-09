module Spree
  module Admin
    module Reports
      module TotalOrders
        class JsonSerializer
          def call(objects)
            serialized_objects = { labels: [], data: [] }

            objects.each do |day, total_orders|
              serialized_objects[:labels].push(day)
              serialized_objects[:data].push(total_orders)
            end

            serialized_objects
          end
        end
      end
    end
  end
end
