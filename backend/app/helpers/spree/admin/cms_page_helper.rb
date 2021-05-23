module Spree
  module Admin
    module CmsPageHelper
      def build_page_section(section)
        preview_type = section.kind.parameterize(separator: '_')

        case section.width
        when 'Full'
          css_width = 'col-12'
        when 'Half'
          css_width = 'col-6'
        end

        render "spree/admin/cms_pages/sections/#{preview_type}", section: section, width: css_width
      end

      def linkable_as_path(item)
        item.parameterize(separator: '_')
      end
    end
  end
end
