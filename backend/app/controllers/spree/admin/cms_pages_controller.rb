module Spree
  module Admin
    class CmsPagesController < ResourceController
      private

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}
        @collection = super

        @search = @collection.ransack(params[:q])
        @collection = @search.result.page(params[:page]).per(params[:per_page])
      end

      def location_after_save
        spree.edit_admin_cms_page_path(@cms_page)
      end
    end
  end
end
