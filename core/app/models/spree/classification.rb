module Spree
  class Classification < Spree.base_class
    self.table_name = 'spree_products_taxons'
    acts_as_list scope: :taxon

    with_options inverse_of: :classifications, touch: true do
      belongs_to :product, class_name: 'Spree::Product'
      belongs_to :taxon, class_name: 'Spree::Taxon'
    end

    validates :taxon, :product, presence: true
    validates :position, numericality: { only_integer: true, allow_blank: true, allow_nil: true }
    # For #3494
    validates :taxon_id, uniqueness: { scope: :product_id, message: :already_linked, allow_blank: true }

    self.whitelisted_ransackable_attributes = ['taxon_id', 'product_id']

    scope :by_best_selling, lambda { |order_direction = :desc|
      left_joins(product: :orders).
        select("#{Spree::Classification.table_name}.*, COUNT(#{Spree::Order.table_name}.id) AS completed_orders_count, SUM(#{Spree::Order.table_name}.total) AS completed_orders_total").
        where(Spree::Order.table_name => { id: nil }).
        or(where.not(Spree::Order.table_name => { completed_at: nil })).
        group("#{Spree::Classification.table_name}.id").
        reorder(completed_orders_count: order_direction, completed_orders_total: order_direction)
    }
  end
end
