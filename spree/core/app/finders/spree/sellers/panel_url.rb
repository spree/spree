module Spree
  module Sellers
    # Origin where the seller panel is hosted, for links that send a seller
    # into it — today the invitation email.
    #
    # Deliberately its own resolver rather than a branch inside
    # `Spree::Stores::DashboardUrl`: the two are different apps for different
    # audiences, and the dashboard's fallback chain (the `/dashboard` mount
    # this app serves, the Vite dev server on 5173) names origins where no
    # seller panel is running.
    #
    # Resolution order, most authoritative first:
    #
    # 1. the `seller_panel_url` preference / SPREE_SELLER_PANEL_URL
    # 2. the dashboard origin, as a last resort
    #
    # The fallback is deliberate. A marketplace that has not deployed a panel
    # still has to send a working invitation, and the staff dashboard at least
    # exists; sending nowhere would be worse. Configure
    # SPREE_SELLER_PANEL_URL and sellers land on their own app.
    class PanelUrl
      # @param store [Spree::Store, nil] store whose URL ends the fallback chain
      # @return [String] origin without a trailing slash, e.g. +https://sellers.shop.com+
      def self.call(store: nil)
        configured = Spree::Config[:seller_panel_url].presence

        return configured.to_s.chomp('/') if configured

        Spree::Stores::DashboardUrl.call(store: store)
      end
    end
  end
end
