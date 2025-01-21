module Spree
  module Pages
    class SearchResults < Spree::Page
      def icon_name
        'search'
      end

      def url
        query = 'test'
        Spree::Core::Engine.routes.url_helpers.search_path(
          q: query,
          theme_id: theme.id,
          page_preview_id: page_preview&.id,
          theme_preview_id: theme_preview&.id,
          locale: I18n.locale
        )
      end

      def preview_url(theme_preview = nil, page_preview = nil)
        query = 'test'
        Spree::Core::Engine.routes.url_helpers.search_path(q: query, theme_id: theme.id, page_preview_id: page_preview&.id, theme_preview_id: theme_preview&.id)
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
