module Spree
  module Admin
    module Reports
      module AverageOrderValues
        class JsonSerializer
          def call(objects)
            serialized_objects = { labels: [], data: [] }

            objects.each do |day, average_order_total|
              serialized_objects[:labels].push(day)
              serialized_objects[:data].push(average_order_total)
            end

            serialized_objects
          end
        end
      end
    end
  end
end
