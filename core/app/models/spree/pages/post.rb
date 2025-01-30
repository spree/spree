module Spree
  module Pages
    class Post < Spree::Page
      page_builder_route_with :post_path, ->(post_page) { post_page.store.posts.published.last }

      def icon_name
        'article'
      end

      def default_sections
        [
          Spree::PageSections::PostDetails.new,
        ]
      end

      def customizable?
        true
      end
    end
  end
end
