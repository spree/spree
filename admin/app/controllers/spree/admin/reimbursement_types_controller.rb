module Spree
  module Admin
    class ReimbursementTypesController < ResourceController
      include Spree::Admin::SettingsConcern

      private

      def permitted_resource_params
        params.require(:reimbursement_type).permit(permitted_reimbursement_type_attributes)
      end
    end
  end
end
