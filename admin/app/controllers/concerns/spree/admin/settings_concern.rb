module Spree
  module Admin
    module SettingsConcern
      extend ActiveSupport::Concern

      included do
        before_action :set_settings_area_flag
      end

      def choose_layout
        return 'turbo_rails/frame' if turbo_frame_request?

        'spree/admin_settings'
      end

      private

      def set_settings_area_flag
        @settings_area = true
      end
    end
  end
end
