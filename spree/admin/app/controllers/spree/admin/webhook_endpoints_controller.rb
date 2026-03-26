# frozen_string_literal: true

module Spree
  module Admin
    class WebhookEndpointsController < ResourceController
      include Spree::Admin::SettingsConcern
      include Spree::Admin::TableConcern

      helper 'spree/admin/webhook_endpoints'

      def test
        load_resource
        authorize! :update, @object
        @object.send_test!
        flash[:success] = Spree.t('admin.webhook_endpoints.test_sent')
        redirect_back(fallback_location: spree.admin_webhook_endpoint_path(@object))
      end

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
