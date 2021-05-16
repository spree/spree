module Spree
  module Admin
    class CmsPagesController < ResourceController
      before_action :load_data

      private

      def load_data
        @page_kinds = Spree::CmsPage::PAGE_KINDS
      end

      def location_after_save
        spree.edit_admin_cms_page_path(@cms_page)
      end
    end
  end
end
