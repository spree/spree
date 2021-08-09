module Spree
  module Admin
    module CmsHelper
      def cms_page_preview_url(page)
        page_localization = if page.locale == current_store.default_locale
                              nil
                            else
                              page.locale
                            end

        spree_storefront_resource_url(page, locale: page_localization)
      end
    end
  end
end
