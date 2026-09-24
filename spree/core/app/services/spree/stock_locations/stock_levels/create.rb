module Spree
  module StockLocations
    module StockLevels
      class Create
        prepend Spree::ServiceModule::Base

        # @param stock_location [Spree::StockLocation]
        # @param variants_scope [ActiveRecord::Relation, nil] defaults to what the
        #   location may stock; always narrowed to it, so no caller can seed rows
        #   for another store's or another seller's variants
        def call(stock_location:, variants_scope: nil)
          variant_ids = propagatable_variants(stock_location, variants_scope).ids
          prepared_stock_levels = variant_ids.map do |variant_id|
            Hash[
              'stock_location_id', stock_location.id,
              'variant_id', variant_id,
              'backorderable', stock_location.backorderable_default,
              'created_at', Time.current,
              'updated_at', Time.current
            ]
          end
          if prepared_stock_levels.any?
            stock_location.stock_levels.insert_all(prepared_stock_levels)
            # By id: MySQL refuses an UPDATE whose own table appears in a subquery.
            Spree::Variant.where(id: variant_ids).touch_all
          end
        end

        private

        # A location stocks its own store's variants, and a seller's location
        # only the variants that seller sells.
        def propagatable_variants(stock_location, variants_scope)
          scope = Spree::Variant.where(id: (variants_scope || Spree::Variant).select(:id))
          scope = scope.for_seller(stock_location.seller_id) if stock_location.seller_id.present?
          scope.joins(:product).where(Spree::Product.table_name => { store_id: stock_location.store_id })
        end
      end
    end
  end
end
