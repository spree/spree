module Spree
  module Admin
    class CmsPagesController < ResourceController

      private

      def location_after_save
        spree.edit_admin_cms_page_path(@cms_page)
      end
    end
  end
end
