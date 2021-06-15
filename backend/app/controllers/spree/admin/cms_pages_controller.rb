module Spree
  module Admin
    class CmsPagesController < ResourceController
      private

      def location_after_save
        spree.edit_admin_cms_page_path(@cms_page)
      end

      def find_resource
        # TODO: replace out the "current_store" for the admin equivelent "current_admin_store"
        # when it is implemented.
        Spree::CmsPage.by_store(current_store).friendly.find(params[:id])
      end
    end
  end
end
