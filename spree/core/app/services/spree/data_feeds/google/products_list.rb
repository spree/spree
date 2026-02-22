module Spree
  module DataFeeds
    module Google
      class ProductsList
        prepend Spree::ServiceModule::Base

        def call(store)
          products = store.products.active
          success(products: products)
        end
      end
    end
  end
end
