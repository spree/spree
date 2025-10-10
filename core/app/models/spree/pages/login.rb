module Spree
  module Pages
    class Login < Spree::Page
      def icon_name
        'key'
      end

      def page_builder_url
        return unless page_builder_url_exists?(:login_path)

        Spree::Core::Engine.routes.url_helpers.login_path
      end

      def linkable?
        true
      end
    end
  end
end
