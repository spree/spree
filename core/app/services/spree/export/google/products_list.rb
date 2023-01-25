module Spree
  module Export
    module Google
      class ProductsList
        prepend Spree::ServiceModule::Base

        def call(store)
          products = store.products.active
          return success(products: products)
        end
      end
    end
  end
end

