module Spree
  module Admin
    class CmsSectionsController < ResourceController
      belongs_to 'spree/cms_page'

      def collection_url
        spree.edit_admin_cms_page_path(@cms_page)
      end

      def location_after_save
        spree.edit_admin_cms_page_cms_section_path(@cms_page, @cms_section)
      end
    end
  end
end
