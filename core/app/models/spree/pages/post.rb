module Spree
  module Pages
    class Post < Spree::Page
      def url
        return unless url_exists?(:post_path)

        post = store.posts.published.last || store.posts.last
        return if post.nil?
        Spree::Core::Engine.routes.url_helpers.post_path(post, locale: I18n.locale)
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
