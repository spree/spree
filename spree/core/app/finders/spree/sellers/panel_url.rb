module Spree
  module Sellers
    # Origin where the seller panel is hosted, for links that send a seller
    # into it — today the invitation email.
    #
    # Resolution order, most authoritative first:
    #
    # 1. the `seller_panel_url` preference / SPREE_SELLER_PANEL_URL
    # 2. the `/sellers` mount this app serves, when a bundle is configured
    # 3. the dashboard origin, as a last resort — accepting there joins the
    #    seller but issues an admin session, so they must sign in again once a
    #    panel exists. Kept rather than raising: a marketplace that has not
    #    deployed one yet still needs to invite people.
    class PanelUrl
      # @param store [Spree::Store, nil] store whose URL ends the fallback chain
      # @return [String] origin without a trailing slash
      def self.call(store: nil)
        configured = Spree::Config[:seller_panel_url].presence
        return configured.to_s.chomp('/') if configured

        mounted_panel_url(store) || dashboard_fallback(store)
      end

      # The `/sellers` mount this app serves, when `spree_dashboard` is
      # installed AND pointed at a seller-panel build. Without a bundle the
      # route 404s, so linking there would be worse than the dashboard.
      def self.mounted_panel_url(store)
        return unless defined?(Spree::Dashboard) && Spree::Dashboard.seller_panel_dist_path.present?

        host = Spree::Stores::DashboardUrl.app_host(store)
        "#{host.chomp('/')}/sellers" if host.present?
      end
      private_class_method :mounted_panel_url

      def self.dashboard_fallback(store)
        Rails.logger.warn(
          '[Spree] No seller panel is configured, so seller invitations point at the staff ' \
          'dashboard. Accepting there joins the seller but issues an admin session, not a ' \
          'seller one. Set SPREE_SELLER_PANEL_URL or serve a seller panel build at /sellers.'
        )

        Spree::Stores::DashboardUrl.call(store: store)
      end
      private_class_method :dashboard_fallback
    end
  end
end
