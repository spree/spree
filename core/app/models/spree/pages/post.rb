module Spree
  module Pages
    class Post < Spree::Page
      def url
        post = store.posts.published.last || store.posts.last

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
