module Spree
  module Pages
    class Login < Spree::Page
      page_builder_route_with :login_path

      def icon_name
        'key'
      end
    end
  end
end
