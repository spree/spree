module Spree
  module StockLocations
    module StockItems
      class Create
        prepend Spree::ServiceModule::Base

        VARIANTS_SCOPE = Spree::Variant
        private_constant :VARIANTS_SCOPE

        def call(stock_location:)
          # [NOTE]: iterating over all variants might attempt to create repeated records, this filter avoids that.
          unrelated_variants = VARIANTS_SCOPE.where.not(id: stock_location.stock_items.pluck(:variant_id))

          # [NOTE]: this checks whether StockLocation defines to +insert_all+ and/or +touch_all+
          #         but +insert_all+ is being invoked on StockItem and +touch_all+ on Variant.
          if stock_location.class.method_defined?(:insert_all) && stock_location.class.method_defined?(:touch_all)
            prepared_stock_items = unrelated_variants.ids.map do |variant_id|
              Hash[
                'stock_location_id', stock_location.id,
                'variant_id', variant_id,
                'backorderable', stock_location.backorderable_default,
                'created_at', Time.current,
                'updated_at', Time.current
              ]
            end
            if prepared_stock_items.any?
              stock_location.stock_items.insert_all(prepared_stock_items)
              VARIANTS_SCOPE.touch_all
            end
          else
            # [NOTE]: +propagate_variant+ receives the whole Variant object, but uses only the id.
            unrelated_variants.find_each do |variant|
              stock_location.propagate_variant(variant)
            end
          end
        end
      end
    end
  end
end
