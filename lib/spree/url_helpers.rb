module Spree
  module UrlHelpers
    def spree_core
      Spree::Core::Engine.routes.url_helpers
    end

    def spree_promo
      Spree::Promo::Engine.routes.url_helpers
    end

    def spree_auth
      Spree::Auth::Engine.routes.url_helpers
    end

    def spree_dash
      Spree::Dash::Engine.routes.url_helpers
    end
  end
end
