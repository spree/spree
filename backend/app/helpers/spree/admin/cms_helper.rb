module Spree
  module Admin
    module CmsHelper
      def page_preview_link(page)
        return unless frontend_available?

        url = if page.homepage?
                spree.root_url + page.locale
              else
                spree.page_url(page.locale, page.slug)
              end

        button_link_to(Spree.t('admin.cms.preview_page'), url, class: 'btn-outline-secondary',
                                                               icon: 'view.svg',
                                                               id: 'admin_preview_product',
                                                               target: :blank)
      end

      def preview_url(page)
        return unless frontend_available?

        if page.homepage?
          spree.root_path + page.locale + "?no_cache=#{rand(1...10000)}"
        else
          "/#{page.locale + spree.page_path(page.slug)}?no_cache=#{rand(1...10000)}"
        end
      end
    end
  end
end
