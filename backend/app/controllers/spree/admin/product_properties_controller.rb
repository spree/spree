module Spree
  module Admin
    class ProductPropertiesController < ResourceController
      belongs_to 'spree/product', find_by: :slug
      before_action :setup_property, only: :index

      def get_properties
        properties = Spree::Property.where("lower(name) LIKE lower(?)", "%#{params[:term]}%").pluck(:name)
        render :json => properties
      end

      private

      def setup_property
        @product.product_properties.build
      end
    end
  end
end
