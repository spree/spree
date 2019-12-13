module Spree
  module Admin
    module Reports
      module Orders
        class TopProductsByUnitSold < Base
          def initialize(params)
            @params = params
          end

          def call
            variants = Spree::Variant.joins(line_items: :order)
            variants = by_date_from(variants)
            variants = by_date_to(variants)

            variants = variants.group('spree_variants.sku')
                               .select('spree_variants.sku, sum(spree_line_items.quantity) as total_quantity_sold')
                               .order(total_quantity_sold: :desc)

            variants = by_top(variants)

            variants.to_a.map { |v| [v.sku, v.total_quantity_sold] }
          end

          private

          def top
            return 5 if params[:top].nil?

            params[:top].to_i
          end

          def by_top(variants)
            return variants unless top

            variants.limit(top)
          end

          def by_date_from(variants)
            return variants unless date_from

            variants.where('spree_orders.completed_at >= ?', date_from.beginning_of_day)
          end

          def by_date_to(variants)
            return variants unless date_to

            variants.where('spree_orders.completed_at <= ?', date_to.end_of_day)
          end
        end
      end
    end
  end
end
