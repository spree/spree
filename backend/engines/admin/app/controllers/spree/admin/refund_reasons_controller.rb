module Spree
  module Admin
    class RefundReasonsController < ResourceController
      include Spree::Admin::SettingsConcern

      private

      def permitted_resource_params
        params.require(:refund_reason).permit(permitted_refund_reason_attributes)
      end
    end
  end
end
