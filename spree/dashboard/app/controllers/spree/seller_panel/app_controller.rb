module Spree
  module SellerPanel
    # Serves the built marketplace seller panel at /sellers.
    #
    # Same origin as the dashboard and the API on purpose: the two panels'
    # refresh cookies are already isolated by name and path, so sharing a host
    # saves every deployment a second hostname and certificate. A marketplace
    # that wants sellers on their own domain deploys the bundle there and
    # points SPREE_SELLER_PANEL_URL at it.
    class AppController < Spree::Dashboard::SpaController
      private

      def dist_path
        Spree::Dashboard.seller_panel_dist_path
      end
    end
  end
end
