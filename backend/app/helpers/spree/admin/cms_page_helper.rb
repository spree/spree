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

      def page_types_dropdown_values
        formatted_types = []

        Spree::CmsPage::PAGE_TYPES.each do |type|
          last_word = type.split('::', 4).last
          readable_type = last_word.gsub(/(?<=[a-z])(?=[A-Z])/, ' ')
          formatted_types << [readable_type, type]
        end

        formatted_types
      end

      def humanize_cms_page_type(page)
        last_word = page.type.split('::', 4).last
        last_word.gsub(/(?<=[a-z])(?=[A-Z])/, ' ')
      end
    end
  end
end
