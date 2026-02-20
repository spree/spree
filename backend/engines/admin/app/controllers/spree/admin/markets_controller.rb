module Spree
  module Admin
    class MarketsController < ResourceController
      include Spree::Admin::SettingsConcern

      before_action :load_data, except: :index

      protected

      def load_data
        @zones = Spree::Zone.order(:name)
      end

      def permitted_resource_params
        params.require(:market).permit(permitted_market_attributes)
      end
    end
  end
end
