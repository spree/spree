module Spree
  module Admin
    class ProductPropertiesController < ResourceController
      belongs_to 'spree/product', :find_by => :permalink
      before_filter :find_properties
      before_filter :setup_property, :only => [:index]

      # We use a "custom" finder in destroy
      # Because the request is scoped without a product
      # on account of the request coming from the "link_to_remove_fields"
      # helper on the admin/product_properties view
      skip_before_filter :load_resource, :only => [:destroy]

      def destroy
        product_property = Spree::ProductProperty.find(params[:id])
        product_property.destroy
        render :text => nil
      end

      private
        def find_properties
          @properties = Spree::Property.pluck(:name)
        end

        def setup_property
          @product.product_properties.build
        end
    end
  end
end
