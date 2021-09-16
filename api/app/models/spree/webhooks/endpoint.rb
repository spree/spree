module Spree
  module Webhooks
    class Endpoint < Spree::Base
      self.table_name = 'spree_webhooks_endpoints'

      before_save :assign_default_subscriptions,
        if: proc { ActiveRecord::Base.connection.adapter_name == 'Mysql2' }

      private

      def assign_default_subscriptions
        self.subscriptions = ['*'] if subscriptions.blank?
      end
    end
  end
end
