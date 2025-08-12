module Spree
  module Admin
    class PoliciesController < ResourceController
      add_breadcrumb Spree.t(:policies), :admin_policies_path

      private

      def collection
        super.order(:position)
      end

      def permitted_resource_params
        params.require(:policy).permit(permitted_policy_attributes)
      end

      def update_turbo_stream_enabled?
        true
      end
    end
  end
end
