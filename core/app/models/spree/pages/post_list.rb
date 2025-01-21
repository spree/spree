module Spree
  module Pages
    class PostList < Spree::Page
      DISPLAY_NAME = Spree.t(:blog).freeze

      def url
        Spree::Core::Engine.routes.url_helpers.posts_path(locale: I18n.locale)
      end

      def icon_name
        'news'
      end

      def default_sections
        [
          Spree::PageSections::PageTitle.new,
          Spree::PageSections::PostGrid.new
        ]
      end

      def display_name
        DISPLAY_NAME
      end

      def customizable?
        true
      end
    end
  end
end
