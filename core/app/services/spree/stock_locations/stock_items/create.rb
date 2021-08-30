module Spree
  module StockLocations
    module StockItems
      class Create
        prepend Spree::ServiceModule::Base

        def call(stock_location:, variants_scope: Spree::Variant)
          if Rails::VERSION::MAJOR >= 6
            prepared_stock_items = variants_scope.ids.map do |variant_id|
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
              variants_scope.touch_all
            end
          else
            variants_scope.find_each do |variant|
              stock_location.propagate_variant(variant)
            end
          end
        end
      end
    end
  end
end
