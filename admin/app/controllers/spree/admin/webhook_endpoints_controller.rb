# frozen_string_literal: true

module Spree
  module Admin
    class WebhookEndpointsController < ResourceController
      include Spree::Admin::SettingsConcern

      helper 'spree/admin/webhook_endpoints'

      private

      def permitted_resource_params
        params.require(:webhook_endpoint).permit(permitted_webhook_endpoint_attributes)
      end

      def location_after_save
        spree.admin_webhook_endpoint_path(@object)
      end

      def update_turbo_stream_enabled?
        true
      end
    end
  end
end
