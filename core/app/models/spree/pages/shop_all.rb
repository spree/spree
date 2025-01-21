module Spree
  module Pages
    class ShopAll < Spree::Page
      def icon_name
        'shopping-bag'
      end

      def url
        Spree::Core::Engine.routes.url_helpers.products_path(locale: I18n.locale)
      end

      def preview_url(theme_preview = nil, page_preview = nil)
        Spree::Core::Engine.routes.url_helpers.products_path(
          theme_id: theme.id,
          page_preview_id: page_preview&.id,
          theme_preview_id: theme_preview&.id
        )
      end

      def default_sections
        [
          Spree::PageSections::PageTitle.new,
          Spree::PageSections::ProductGrid.new
        ]
      end

      def customizable?
        true
      end
    end
  end
end
