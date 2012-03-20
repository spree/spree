module Spree
  module Admin
    class ProductPropertiesController < ResourceController
      belongs_to 'spree/product', :find_by => :permalink
      before_filter :find_properties

      private
        def find_properties
          @properties = Spree::Property.pluck(:name)
        end
    end
  end
end
