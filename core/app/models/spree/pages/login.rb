module Spree
  module Pages
    class Login < Spree::Page
      def icon_name
        'key'
      end

      def url
        return unless url_exists?(:login_path)

        Spree::Core::Engine.routes.url_helpers.login_path(locale: I18n.locale)
      end
    end
  end
end
