module Spree
  module Admin
    module TurboFrameLayoutConcern
      extend ActiveSupport::Concern

      included do
        layout :choose_layout
      end

      def choose_layout
        return 'turbo_rails/frame' if turbo_frame_request?

        'spree/admin'
      end
    end
  end
end
