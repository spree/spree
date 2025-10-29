module Spree
  module Pages
    class PostList < Spree::Page
      DISPLAY_NAME = Spree.t(:blog).freeze

      def page_builder_url
        return unless page_builder_url_exists?(:posts_path)

        Spree::Core::Engine.routes.url_helpers.posts_path
      end

      def icon_name
        'news'
      end

      def default_sections
        [
          Spree::PageSections::PageTitle.new(preferred_title: DISPLAY_NAME),
          Spree::PageSections::PostGrid.new
        ]
      end

      def display_name
        DISPLAY_NAME
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
