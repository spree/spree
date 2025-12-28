# frozen_string_literal: true

module Spree
  module Admin
    class WebhookDeliveriesController < ResourceController
      include Spree::Admin::SettingsConcern

      helper 'spree/admin/webhook_endpoints'

      belongs_to 'spree/webhook_endpoint'

      private

      def collection_default_sort
        'created_at desc'
      end
    end
  end
end
