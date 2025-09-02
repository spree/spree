module Spree
  module Pages
    class Checkout < Spree::Page
      def page_builder_url
        return unless page_builder_url_exists?(:checkout_path)

        Spree::Core::Engine.routes.url_helpers.checkout_path
      end

      def icon_name
        'credit-card'
      end
    end
  end
end
