module Spree
  module Admin
    module SettingsConcern
      extend ActiveSupport::Concern

      def choose_layout
        return 'turbo_rails/frame' if turbo_frame_request?

        'spree/admin_settings'
      end
    end
  end
end
