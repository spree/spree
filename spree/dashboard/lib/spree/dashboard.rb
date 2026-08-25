require 'spree'

module Spree
  module Dashboard
    class << self
      # Directory holding a built React Dashboard (`vite build` output),
      # served at /dashboard. Set from an initializer, or via the
      # SPREE_DASHBOARD_DIST_PATH env var (which the official Docker image
      # and the Render Blueprint use). Unset, /dashboard responds 404.
      attr_writer :dist_path

      def dist_path
        @dist_path.presence || ENV.fetch('SPREE_DASHBOARD_DIST_PATH', nil)
      end

      # Directory holding a built marketplace seller panel, served at
      # /sellers. A separate bundle rather than the dashboard's: it is a
      # different app — its own entry point, router and API client — so
      # pointing both mounts at one directory would serve sellers the
      # operator's back office. Unset, /sellers responds 404.
      attr_writer :seller_panel_dist_path

      def seller_panel_dist_path
        @seller_panel_dist_path.presence || ENV.fetch('SPREE_SELLER_PANEL_DIST_PATH', nil)
      end
    end
  end
end

require 'spree/dashboard/engine'
