# frozen_string_literal: true

module Spree
  module Admin
    class WebhookDeliveriesController < ResourceController
      include Spree::Admin::SettingsConcern

      helper 'spree/admin/webhook_endpoints'

      belongs_to 'spree/webhook_endpoint'

      def retry
        if @webhook_delivery.webhook_endpoint.active?
          Spree::WebhookDeliveryJob.perform_later(@webhook_delivery.id, @webhook_delivery.webhook_endpoint.secret_key)
          flash[:success] = Spree.t('admin.webhook_deliveries.retry_queued')
        else
          flash[:error] = Spree.t('admin.webhook_deliveries.endpoint_inactive')
        end
        redirect_to spree.admin_webhook_endpoint_webhook_deliveries_path(@webhook_delivery.webhook_endpoint)
      end

      private

      def collection_default_sort
        'created_at desc'
      end
    end
  end
end
