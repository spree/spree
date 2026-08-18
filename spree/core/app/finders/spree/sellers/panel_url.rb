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
    # 2. the `/sellers` mount this app serves, when a bundle is configured
    # 3. the dashboard origin, as a last resort
    #
    # The last fallback is deliberate. A marketplace that has not deployed a
    # panel still has to send a working invitation, and the staff dashboard at
    # least exists; sending nowhere would be worse.
    class PanelUrl
      # @param store [Spree::Store, nil] store whose URL ends the fallback chain
      # @return [String] origin without a trailing slash, e.g. +https://sellers.shop.com+
      def self.call(store: nil)
        configured = Spree::Config[:seller_panel_url].presence

        return configured.to_s.chomp('/') if configured

        mounted_panel_url(store) || Spree::Stores::DashboardUrl.call(store: store)
      end

      # The `/sellers` mount this app serves, when `spree_dashboard` is
      # installed AND pointed at a seller-panel build. Without a bundle the
      # route 404s, so linking there would be worse than the dashboard.
      # @return [String, nil]
      def self.mounted_panel_url(store)
        return unless defined?(Spree::SellerPanel) && Spree::SellerPanel.dist_path.present?

        host = Spree::Stores::DashboardUrl.app_host(store)
        return if host.blank?

        "#{host.chomp('/')}/sellers"
      end
      private_class_method :mounted_panel_url
    end
  end
end
