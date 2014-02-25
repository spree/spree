module Spree
  module Admin
    class PropertiesController < ResourceController
      def index
        respond_with(@collection)
      end

      private

      def collection
        return @collection if @collection.present?
        params[:q] ||= {}

        @collection = super
        @search = @collection.ransack(params[:q])
        @collection = @search.result.
              page(params[:page]).
              per(Spree::Config[:properties_per_page])

        @collection
      end
    end
  end
end
