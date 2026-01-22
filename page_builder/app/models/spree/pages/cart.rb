module Spree
  module Pages
    class Cart < Spree::Page
      def page_builder_url
        return unless page_builder_url_exists?(:cart_path)

        Spree::Core::Engine.routes.url_helpers.cart_path
      end

      def icon_name
        'shopping-cart'
      end

      def linkable?
        true
      end
    end
  end
end
