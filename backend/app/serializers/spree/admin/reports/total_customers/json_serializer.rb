module Spree
  module Admin
    module Reports
      module TotalCustomers
        class JsonSerializer
          def call(objects)
            serialized_objects = { labels: [], data: [] }

            objects.each do |day, total_customers|
              serialized_objects[:labels].push(day)
              serialized_objects[:data].push(total_customers)
            end

            serialized_objects
          end
        end
      end
    end
  end
end
