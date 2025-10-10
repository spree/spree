module Spree
  module Pages
    class Wishlist < Spree::Page
      def page_builder_url
        return unless page_builder_url_exists?(:account_wishlist_path)

        Spree::Core::Engine.routes.url_helpers.account_wishlist_path
      end

      def linkable?
        true
      end
    end
  end
end
