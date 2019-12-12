module Spree
  module Admin
    module Reports
      module Orders
        class TopProductsByLineItemTotals < Base
          def initialize(params)
            @params = params
            @top = params[:top]
          end

          def call
            variants = Spree::Variant.joins(:prices, line_items: :order)
            variants = by_completed_at_min(variants)
            variants = by_completed_at_max(variants)

            variants = variants.group('spree_variants.sku')
                               .select('spree_variants.sku, sum(spree_line_items.quantity * spree_prices.amount) as line_item_total')
                               .order(line_item_total: :desc)

            variants = by_top(variants)

            variants.to_a.map { |v| [v.sku, v.line_item_total] }
          end

          private

          attr_reader :top

          def by_top(variants)
            return variants if top.nil?

            variants.limit(top)
          end

          def by_completed_at_min(variants)
            return variants unless completed_at_min

            variants.where('spree_orders.completed_at >= ?', completed_at_min.beginning_of_day)
          end

          def by_completed_at_max(variants)
            return variants unless completed_at_max

            variants.where('spree_orders.completed_at <= ?', completed_at_max.end_of_day)
          end
        end
      end
    end
  end
end
