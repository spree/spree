module Spree
  module Pages
    class Account < Spree::Page
      page_builder_route_with :account_path

      def icon_name
        'user'
      end
    end
  end
end
