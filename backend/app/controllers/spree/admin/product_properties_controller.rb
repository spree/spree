module Spree
  module Admin
    class ProductPropertiesController < ResourceController
      belongs_to 'spree/product'
      before_action :find_properties
      before_action :setup_property, only: :index

      private

        def setup_property
          @product.product_properties.build if !@product.product_properties.any?
        end

        def find_properties
          @properties = Spree::Property.all
        end
    end
  end
end
