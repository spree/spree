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
    end
  end
end

require 'spree/dashboard/engine'
