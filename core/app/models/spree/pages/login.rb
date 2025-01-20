module Spree
  module Pages
    class Login < Spree::Page
      def icon_name
        'key'
      end

      def url
        Spree::Core::Engine.routes.url_helpers.login_path(locale: I18n.locale)
      end
    end
  end
end
