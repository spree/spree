module Spree
  module Admin
    module Reports
      module Orders
        class TopProductsByUnitSold < Base
          def initialize(params)
            @params = params
          end

          def call
            orders = Spree::Order.eager_load(line_items: :variant).complete
            orders = by_completed_at_min(orders)
            orders = by_completed_at_max(orders)
            line_items = orders.map(&:line_items).flatten

            line_items.group_by(&:variant)
                      .transform_keys { |variant| variant.sku }
                      .transform_values { |line_items| line_items.map(&:quantity).sum }
                      .to_a
                      .sort_by { |_, number_of_items_sold| -number_of_items_sold }
          end
        end
      end
    end
  end
end
