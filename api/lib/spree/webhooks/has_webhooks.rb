module Spree
  module Webhooks
    module HasSpreeWebhooks
      extend ActiveSupport::Concern

      module ClassMethods
        def has_spree_webhooks(on: [])
          Array(on).each do |action|
            public_send(:after_commit, on: action) do
              execute_webhook_logic!
            end
          end
        end
      end

      private

      def execute_webhook_logic!
        self.name = 'execute_webhook_logic!'
        self.save
      end
    end
  end
end
