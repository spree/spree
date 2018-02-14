module Spree
  module Admin
    class PropertiesController < ResourceController
      def index
        respond_with(@collection)
      end

      private

      def collection
        return @collection if @collection.present?
        # params[:q] can be blank upon pagination
        params[:q] = {} if params[:q].blank?

        @collection = super
        @search = @collection.ransack(params[:q])
        @collection = @search.result.
                      page(params[:page]).
                      per(Spree::Config[:admin_properties_per_page])
      end
    end
  end
end
