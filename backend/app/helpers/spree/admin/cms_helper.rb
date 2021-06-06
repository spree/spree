module Spree
  module Admin
    module CmsHelper
      def build_page_section(section)
        css_width = case section.width
                    when 'Half'
                      'col-6'
                    else
                      'col-12'
                    end

        boundary = case section.boundary
                   when 'Screen'
                     'edge'
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
                spree.root_url + page.locale
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
          spree.root_path + page.locale
        else
          spree.page_path(page.slug)
        end
      end
    end
  end
end
