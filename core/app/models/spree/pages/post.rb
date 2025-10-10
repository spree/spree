module Spree
  module Pages
    class Post < Spree::Page
      def page_builder_url
        return unless page_builder_url_exists?(:post_path)

        post = store.posts.published.last || store.posts.last
        return if post.nil?
        Spree::Core::Engine.routes.url_helpers.post_path(post)
      end

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
