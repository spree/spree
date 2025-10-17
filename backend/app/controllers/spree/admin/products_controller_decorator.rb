module Spree
  module Admin
    module ProductsControllerDecorator
      def self.prepended(base)
        base.include Spree::Admin::ProductsHelper
      end

      def collection
        return @collection if @collection
        @collection = super
        
        # Add tag search functionality
        if params[:q] && params[:q][:tags_name_cont].present?
          @collection = @collection.tagged_with(params[:q][:tags_name_cont])
        end
        
        @collection
      end
    end
  end
end

Spree::Admin::ProductsController.prepend Spree::Admin::ProductsControllerDecorator
