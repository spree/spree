module Spree
  class StoreProduct < Spree.base_class
    self.table_name = 'spree_products_stores'

    belongs_to :store, class_name: 'Spree::Store', touch: true
    belongs_to :product, class_name: 'Spree::Product', touch: true

    validates :store, :product, presence: true
    validates :store_id, uniqueness: { scope: :product_id }

    def refresh_metrics!
      return if product.nil?

      completed_order_ids = product.completed_orders.where(store_id: store_id).select(:id)
      variant_ids = product.variants_including_master.ids

      line_items = Spree::LineItem.joins(:order)
        .where(spree_orders: { id: completed_order_ids })
        .where(variant_id: variant_ids)

      update!(
        units_sold_count: line_items.sum(:quantity),
        revenue: line_items.sum(:pre_tax_amount)
      )
    end
  end
end
