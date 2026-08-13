module Spree
  module Stores
    # Origin where the React dashboard is hosted, for every link that sends
    # someone into it: invitation emails, the SSO callback, the first-run
    # setup link.
    #
    # Configure it with the SPREE_DASHBOARD_URL environment variable (read
    # through the `dashboard_url` preference). The fallbacks exist so links
    # still work in dev and on installs that never set it — the Vite dev
    # server in development, then the store's own URL — but neither is a
    # substitute for configuring the real origin in production.
    class DashboardUrl
      # @param store [Spree::Store, nil] store whose URL ends the fallback chain
      # @return [String] origin without a trailing slash, e.g. +https://admin.shop.com+
      def self.call(store: nil)
        base = Spree::Config[:dashboard_url].presence ||
               legacy_admin_url ||
               (Rails.env.development? ? 'http://localhost:5173' : nil) ||
               store&.formatted_url

        base.to_s.chomp('/')
      end

      # Reads the deprecated `admin_url` without tripping its warning on every
      # link — the warning belongs to whoever set it, and Spree::Config[] would
      # emit one per call here.
      # @return [String, nil]
      def self.legacy_admin_url
        Spree::Config.admin_url.presence
      end
      private_class_method :legacy_admin_url
    end
  end
end
