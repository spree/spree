module Spree
  module PageSections
    class PageTitle < Spree::PageSection
      preference :title, :string

      def icon_name
        'heading'
      end

      def display_name
        if pageable.is_a?(Spree::Page) && pageable.custom?
          pageable.name
        else
          Spree.t('page_sections.page_title.display_name')
        end
      end
    end
  end
end
