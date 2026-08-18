module Spree
  module SellerPanel
    # Serves the built marketplace seller panel at /sellers.
    #
    # Same origin as the dashboard and the API on purpose: the two panels'
    # refresh cookies are already isolated by name and path
    # (`/api/v3/admin/auth` vs `/api/v3/seller/auth`), so sharing a host costs
    # nothing in isolation and saves every deployment a second hostname and
    # certificate. A marketplace that wants sellers on their own domain
    # deploys the bundle there and points SPREE_SELLER_PANEL_URL at it.
    #
    # The dist directory comes from `Spree::SellerPanel.dist_path`; when
    # unset, /sellers 404s — a marketplace that runs no seller panel serves
    # nothing rather than an empty shell.
    class AppController < Spree::Dashboard::SpaController
      private

      def dist_path
        Spree::SellerPanel.dist_path
      end
    end
  end
end
