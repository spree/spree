module Spree
  module Pages
    class ShopAll < Spree::Page
      def icon_name
        'shopping-bag'
      end

      def page_builder_url
        return unless page_builder_url_exists?(:products_path)

        Spree::Core::Engine.routes.url_helpers.products_path
      end

      def preview_url(theme_preview = nil, page_preview = nil)
        return unless page_builder_url_exists?(:products_path)

        Spree::Core::Engine.routes.url_helpers.products_path(
          theme_id: theme.id,
          page_preview_id: page_preview&.id,
          theme_preview_id: theme_preview&.id
        )
      end

      def default_sections
        [
          Spree::PageSections::PageTitle.new(preferred_title: Spree.t(:shop_all)),
          Spree::PageSections::ProductGrid.new
        ]
      end

      def customizable?
        true
      end

      def linkable?
        true
      end
    end
  end
end
