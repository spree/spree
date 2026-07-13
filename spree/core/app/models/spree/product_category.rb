module Spree
  # Join model between Spree::Product and Spree::Category. Renamed from
  # Spree::Classification in 6.0 (Spree::Classification kept as a deprecation
  # alias). The category_id column was renamed in 6.0, so the association is a
  # plain #category with no foreign_key override.
  class ProductCategory < Spree.base_class
    acts_as_list scope: :category_id

    with_options inverse_of: :product_categories, touch: true do
      belongs_to :product, class_name: 'Spree::Product', counter_cache: :categories_count
      belongs_to :category, class_name: 'Spree::Category'
    end

    validates :category, :product, presence: true
    validates :position, numericality: { only_integer: true, allow_blank: true, allow_nil: true }
    # For #3494
    validates :category_id, uniqueness: { scope: :product_id, message: :already_linked, allow_blank: true }

    # Keep the category's descendant-inclusive products_count (and its ancestors')
    # in sync on direct create/destroy. Bulk Categories::AddProducts/RemoveProducts
    # skip these callbacks and recompute explicitly.
    after_create :recalculate_category_products_count
    after_destroy :recalculate_category_products_count

    self.whitelisted_ransackable_attributes = ['category_id', 'product_id']

    scope :by_best_selling, lambda { |order_direction = :desc|
      left_joins(product: :orders).
        select("#{Spree::ProductCategory.table_name}.*, COUNT(#{Spree::Order.table_name}.id) AS completed_orders_count, SUM(#{Spree::Order.table_name}.total) AS completed_orders_total").
        where(Spree::Order.table_name => { id: nil }).
        or(where.not(Spree::Order.table_name => { completed_at: nil })).
        group("#{Spree::ProductCategory.table_name}.id").
        reorder(completed_orders_count: order_direction, completed_orders_total: order_direction)
    }

    scope :grouped_category_ids_for_products, lambda { |product_ids, category_groups|
      where(product_id: product_ids, category_id: category_groups).
        group(:product_id).
        then do |query|
        case ActiveRecord::Base.connection.adapter_name
        when 'PostgreSQL'
          query.pluck(:product_id, Arel.sql("STRING_AGG(category_id::text, ',')"))
        when 'Mysql2', 'SQLite'
          query.pluck(:product_id, Arel.sql('GROUP_CONCAT(category_id)'))
        end
      end
    }

    # @deprecated Use #category / #category=; removed in 6.1.
    def taxon
      category
    end

    def taxon=(value)
      self.category = value
    end

    private

    def recalculate_category_products_count
      Spree::Category.recalculate_products_count(category_id)
    end
  end
end
