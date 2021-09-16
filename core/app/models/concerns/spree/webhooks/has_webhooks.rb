module Spree
  module Webhooks
    module HasWebhooks
      extend ActiveSupport::Concern

      included do
        after_create_commit proc { execute_webhook_logic!(event_name(:create)) },
          unless: proc { webhooks_descendant? }
        after_destroy_commit proc { execute_webhook_logic!(event_name(:destroy)) },
          unless: proc { webhooks_descendant? }
        after_update_commit proc { execute_webhook_logic!(event_name(:update)) },
          unless: proc { webhooks_descendant? }

        def execute_webhook_logic!(event)
          Spree::Webhooks::Endpoints::QueueRequests.call(event: event)
        end

        private

        def webhooks_descendant?
          self.class.module_parents.include?(Spree::Webhooks)
        end

        def event_name(operation)
          "#{self.class.name.demodulize.downcase}.#{operation}"
        end
      end
    end
  end
end
