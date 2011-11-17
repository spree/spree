module Spree
  module UrlHelpers
    def spree
      Spree::Core::Engine.routes.url_helpers
    end
  end
end
