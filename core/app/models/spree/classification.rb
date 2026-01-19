module Spree
  class Classification < Spree.base_class
    self.table_name = 'spree_products_taxons'
    acts_as_list scope: :taxon

    with_options inverse_of: :classifications, touch: true do
      belongs_to :product, class_name: 'Spree::Product', counter_cache: :classification_count
      belongs_to :taxon, class_name: 'Spree::Taxon', counter_cache: :classification_count
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

    scope :grouped_taxon_ids_for_products, lambda { |product_ids, taxon_groups|
      where(product_id: product_ids, taxon_id: taxon_groups).
        group(:product_id).
        then do |query|
        case ActiveRecord::Base.connection.adapter_name
        when 'PostgreSQL'
          query.pluck(:product_id, Arel.sql("STRING_AGG(taxon_id::text, ',')"))
        when 'Mysql2', 'SQLite'
          query.pluck(:product_id, Arel.sql('GROUP_CONCAT(taxon_id)'))
        end
      end
    }
  end
end
