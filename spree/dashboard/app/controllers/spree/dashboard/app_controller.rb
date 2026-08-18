module Spree
  module Dashboard
    # Serves the built React Dashboard at /dashboard. Everything about how a
    # bundle is served lives in SpaController; this names which bundle.
    #
    # The dist directory comes from `Spree::Dashboard.dist_path` (the official
    # Docker image sets it via SPREE_DASHBOARD_DIST_PATH); when unset,
    # /dashboard 404s.
    class AppController < SpaController
      private

      def dist_path
        Spree::Dashboard.dist_path
      end
    end
  end
end
