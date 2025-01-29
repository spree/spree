module Spree
  module Pages
    class Account < Spree::Page
      def page_builder_url
        return unless page_builder_url_exists?(:account_path)

        Spree::Core::Engine.routes.url_helpers.account_path(locale: I18n.locale)
      end

      def icon_name
        'user'
      end
    end
  end
end
