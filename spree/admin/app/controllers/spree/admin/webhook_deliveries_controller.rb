# frozen_string_literal: true

module Spree
  module Admin
    class WebhookDeliveriesController < ResourceController
      include Spree::Admin::SettingsConcern
      include Spree::Admin::TableConcern

      helper 'spree/admin/webhook_endpoints'

      belongs_to 'spree/webhook_endpoint'

      def redeliver
        load_resource
        authorize! :update, @object.webhook_endpoint
        new_delivery = @object.redeliver!
        flash[:success] = Spree.t('admin.webhook_deliveries.redelivered')
        redirect_back(fallback_location: spree.admin_webhook_endpoint_webhook_delivery_path(@object.webhook_endpoint, new_delivery))
      end

      private

      def collection_default_sort
        'created_at desc'
      end
    end
  end
end
