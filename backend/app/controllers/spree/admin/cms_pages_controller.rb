module Spree
  module Admin
    class CmsPagesController < ResourceController
      before_action :load_data

      private

      def load_data
        @page_types = Spree::CmsPage::PAGE_TYPES
      end

      def location_after_save
        spree.edit_admin_cms_page_path(@cms_page)
      end
    end
  end
end
