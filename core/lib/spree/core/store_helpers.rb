# Methods added to this helper will be available to all templates in the application.
module Spree
  module Core
    module StoreHelpers

      # helper to determine if its appropriate to show the store menu
      def store_menu?
        %w{thank_you}.exclude? params[:action]
      end

    end
  end
end
