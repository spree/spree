module Spree
  module Products
    class RefreshMetricsJob < Spree::BaseJob
      queue_as Spree.queues.products

      def perform(product_id)
        product = Spree::Product.find_by(id: product_id)
        return unless product

        completed_order_ids = product.completed_orders.select(:id)
        variant_ids = product.variants.ids

        line_items = Spree::LineItem.joins(:order)
          .where(spree_orders: { id: completed_order_ids })
          .where(variant_id: variant_ids)

        # update columns to skip callbacks
        product.update_columns(
          units_sold_count: line_items.sum(:quantity),
          revenue: line_items.sum(:pre_tax_amount)
        )
      end
    end
  end
end
