module Spree
  class Classification < Spree.base_class
    # Phase 2 transitional: table + FK column renamed (spree_products_taxons ->
    # spree_product_categories, taxon_id -> category_id). The class rename to
    # Spree::ProductCategory is Phase 4; the :taxon association stays, pointed at
    # the renamed FK. The taxon-side counter_cache (classification_count) is gone —
    # the descendant-inclusive products_count is kept up to date separately.
    self.table_name = 'spree_product_categories'
    acts_as_list scope: :category_id

    with_options inverse_of: :classifications, touch: true do
      belongs_to :product, class_name: 'Spree::Product', counter_cache: :categories_count
      belongs_to :taxon, class_name: 'Spree::Taxon', foreign_key: :category_id
    end

    validates :taxon, :product, presence: true
    validates :position, numericality: { only_integer: true, allow_blank: true, allow_nil: true }
    # For #3494
    validates :category_id, uniqueness: { scope: :product_id, message: :already_linked, allow_blank: true }

    # Keep the taxon's descendant-inclusive products_count (and its ancestors')
    # in sync on direct create/destroy. Bulk Taxons::AddProducts/RemoveProducts
    # skip these callbacks and recompute explicitly.
    after_create :recalculate_taxon_products_count
    after_destroy :recalculate_taxon_products_count

    self.whitelisted_ransackable_attributes = ['category_id', 'product_id']

    scope :by_best_selling, lambda { |order_direction = :desc|
      left_joins(product: :orders).
        select("#{Spree::Classification.table_name}.*, COUNT(#{Spree::Order.table_name}.id) AS completed_orders_count, SUM(#{Spree::Order.table_name}.total) AS completed_orders_total").
        where(Spree::Order.table_name => { id: nil }).
        or(where.not(Spree::Order.table_name => { completed_at: nil })).
        group("#{Spree::Classification.table_name}.id").
        reorder(completed_orders_count: order_direction, completed_orders_total: order_direction)
    }

    scope :grouped_taxon_ids_for_products, lambda { |product_ids, taxon_groups|
      where(product_id: product_ids, category_id: taxon_groups).
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

    private

    def recalculate_taxon_products_count
      Spree::Taxon.recalculate_products_count(category_id)
    end
  end
end
