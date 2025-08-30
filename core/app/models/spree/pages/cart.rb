module Spree
  module Pages
    class Cart < Spree::Page
      def icon_name
        'shopping-cart'
      end

      def linkable?
        true
      end
    end
  end
end
