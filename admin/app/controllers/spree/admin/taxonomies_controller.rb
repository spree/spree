module Spree
  module Admin
    class TaxonomiesController < ResourceController
      private

      def collection
        return @collection if @collection.present?

        @collection = super

        params[:q] ||= {}
        @search = @collection.ransack(params[:q])
        @collection = @search.result.all
      end

      def location_after_save
        spree.admin_taxonomy_path(@taxonomy)
      end
    end
  end
end
