module Spree
  module Admin
    module CmsHelper
      def page_preview_link(page)
        page_localization = if page.locale == current_store.default_locale
                              nil
                            else
                              page.locale
                            end
        button_link_to(Spree.t('admin.cms.preview_page'),
                       spree_storefront_resource_url(page, locale: page_localization),
                       class: 'btn-outline-secondary',
                       icon: 'view.svg',
                       id: 'admin_preview_product',
                       target: :blank)
      end

      def preview_url(page)
        page_localization = if page.locale == current_store.default_locale
                              nil
                            else
                              page.locale
                            end

        spree_storefront_resource_url(page, locale: page_localization) + "?no_cache=#{rand(1...10000)}"
      end
    end
  end
end
