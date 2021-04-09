module Spree
  module Admin
    class MenusController < ResourceController
      def index
        @menus = Spree::Menu.all
      end
    end
  end
end
