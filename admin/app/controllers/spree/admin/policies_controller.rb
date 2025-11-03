module Spree
  module Admin
    class PoliciesController < ResourceController
      include Spree::Admin::SettingsConcern

      before_action :set_policy_owner, only: %i[create update]

      private

      def permitted_resource_params
        params.require(:policy).permit(permitted_policy_attributes)
      end

      def update_turbo_stream_enabled?
        true
      end

      def set_policy_owner
        @policy.owner ||= current_store
      end

      def object_url(object = nil, options = {})
        target = object || @object
        spree.admin_policy_url(target&.id, options)
      end
    end
  end
end
