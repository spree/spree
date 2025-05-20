module Spree
  module Admin
    class RefundReasonsController < ResourceController
      add_breadcrumb Spree.t(:refund_reasons), :admin_refund_reasons_path

      private

      def permitted_resource_params
        params.require(:refund_reason).permit(permitted_refund_reason_attributes)
      end
    end
  end
end
