module Spree
  module Stores
    # Origin where the React dashboard is hosted, for every link that sends
    # someone into it: invitation emails, the SSO callback, the first-run
    # setup link.
    #
    # Resolution order, most authoritative first:
    #
    # 1. the `dashboard_url` preference / SPREE_DASHBOARD_URL — an explicit
    #    answer always wins
    # 2. the deprecated `admin_url` preference
    # 3. the dashboard this app serves itself, when `spree_dashboard` is
    #    installed and has a build to serve (`/dashboard` on the app's own
    #    host) — a fact about this deployment, so it beats the guess below
    # 4. the Vite dev server in development, for the monorepo/CLI workflow
    #    where the dashboard runs as a separate process
    # 5. the store's own URL
    #
    # Steps 3-5 keep links working on installs that never configured an
    # origin; none is a substitute for setting SPREE_DASHBOARD_URL in
    # production, where the app's own host is rarely where admins go.
    class DashboardUrl
      # @param store [Spree::Store, nil] store whose URL ends the fallback chain
      # @return [String] origin without a trailing slash, e.g. +https://admin.shop.com+
      def self.call(store: nil)
        base = Spree::Config[:dashboard_url].presence ||
               legacy_admin_url ||
               mounted_dashboard_url(store) ||
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

      # The `/dashboard` mount served by this app, when `spree_dashboard` is
      # installed AND pointed at a build. Without a build the route 404s, so
      # linking there would be worse than the dev-server guess.
      # @return [String, nil]
      def self.mounted_dashboard_url(store)
        return unless defined?(Spree::Dashboard) && Spree::Dashboard.dist_path.present?

        host = app_host(store)
        return if host.blank?

        "#{host.chomp('/')}/dashboard"
      end
      private_class_method :mounted_dashboard_url

      # Where this Rails app answers. `default_url_options` is what mailers
      # already rely on, so a deployment that gets email links right gets this
      # right too; the store URL is the last resort.
      #
      # Public because the seller panel resolves its own `/sellers` mount
      # against the same host — both are asking where this app serves.
      # @return [String, nil]
      def self.app_host(store)
        options = Rails.application.routes.default_url_options
        return store&.formatted_url if options[:host].blank?

        protocol = options[:protocol].presence || 'http'
        port = options[:port]
        host = "#{protocol}://#{options[:host]}"
        port.present? ? "#{host}:#{port}" : host
      end
    end
  end
end
