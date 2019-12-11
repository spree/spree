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

            line_items = line_items.group_by(&:variant)
                                   .transform_keys { |variant| variant.sku }
                                   .transform_values { |line_items| line_items.map(&:quantity).sum.round(2) }
                                   .to_a
                                   .sort_by { |_, number_of_items_sold| -number_of_items_sold }

            line_items = by_top(line_items)

            line_items
          end

          private

          def top
            return nil if params[:top].nil?

            params[:top].to_i
          end

          def by_top(line_items)
            return line_items unless top

            line_items.first(top)
          end
        end
      end
    end
  end
end

# Spree::Variant.joins(line_items: :order)
#               .where(spree_orders: { state: 'complete', completed_at: date_from..date_to })
#               .group('spree_variants.sku').select('spree_variants.sku, sum(spree_line_items.quantity) as total_quantity_sold')
#               .order(total_quantity_sold: :desc)
#               .limit(5)
#               .to_a
#               .map { |v| [v.sku, v.total_quantity_sold] }
