module Spree
  module Pages
    class Wishlist < Spree::Page
      def url
        Spree::Core::Engine.routes.url_helpers.account_wishlist_path(locale: I18n.locale)
      end
    end
  end
end
