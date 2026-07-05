module Spree
  module Admin
    class ChannelsController < ResourceController
      include Spree::Admin::SettingsConcern

      private

      def permitted_resource_params
        params.require(:channel).permit(permitted_channel_attributes)
      end
    end
  end
end
