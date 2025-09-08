module Spree
  module Admin
    class PoliciesController < ResourceController
      add_breadcrumb Spree.t(:policies), :admin_policies_path

      private

      def collection
        model_class.accessible_by(current_ability, :manage)
      end

      def find_resource
        model_class.accessible_by(current_ability, :manage).friendly.find(params[:id])
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
