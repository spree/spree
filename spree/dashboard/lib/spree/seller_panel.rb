require 'spree'

module Spree
  module SellerPanel
    class << self
      # Directory holding a built seller panel (`vite build` output), served
      # at /sellers. Set from an initializer, or via the
      # SPREE_SELLER_PANEL_DIST_PATH env var. Unset, /sellers responds 404 —
      # a marketplace that runs no seller panel serves nothing.
      attr_writer :dist_path

      def dist_path
        @dist_path.presence || ENV.fetch('SPREE_SELLER_PANEL_DIST_PATH', nil)
      end
    end
  end
end
