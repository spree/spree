module Spree
  module Core
    module UrlHelpers
      def spree
        Spree::Core::Engine.routes.url_helpers
      end
    end
  end
end
