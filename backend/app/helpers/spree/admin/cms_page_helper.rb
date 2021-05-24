module Spree
  module Admin
    module CmsPageHelper
      def build_page_section(section)
        preview_type = section.kind.parameterize(separator: '_')

        case section.width
        when 'Half'
          css_width = 'col-6'
        when 'Full'
          css_width = 'col-12'
        when 'Edge-to-Edge'
          css_width = 'col-12 px-0 edge'
        end

        render "spree/admin/cms_pages/section_template", section: section, width: css_width
      end

      def linkable_as_path(item)
        item.parameterize(separator: '_')
      end
    end
  end
end
