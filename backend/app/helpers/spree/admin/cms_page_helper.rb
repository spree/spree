module Spree
  module Admin
    module CmsPageHelper
      def build_page_section(section)
        css_width = case section.width
                    when 'Half'
                      'col-6'
                    else
                      'col-12'
                    end

        boundary = case section.boundary
                   when 'Screen'
                     'px-0 edge'
                   else
                     ''
                   end

        render 'spree/admin/cms_pages/section_template',
               section: section,
               width: css_width,
               boundary: boundary
      end

      def page_preview_link(page)
        return unless frontend_available?

        url = if page.homepage?
                spree.root_url
              else
                spree.page_url(page.slug)
              end

        button_link_to(
          Spree.t(:preview_page),
          url,
          class: 'btn-outline-secondary', icon: 'view.svg', id: 'admin_preview_product', target: :blank
        )
      end

      def preview_url(page)
        return unless frontend_available?

        if page.homepage?
          spree.root_path
        else
          spree.page_path(page.slug)
        end
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

      def humanize_cms_type(obj)
        last_word = obj.type.split('::', 4).last
        last_word.gsub(/(?<=[a-z])(?=[A-Z])/, ' ')
      end

      def parametize_cms_type(obj)
        last_word = obj.type.split('::', 4).last
        last_word.parameterize(separator: '_')
      end
    end
  end
end
