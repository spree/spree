module Spree
  module Webhooks
    module HasWebhooks
      extend ActiveSupport::Concern

      included do
        after_create_commit proc { queue_webhooks_requests!(event_name(:create)) },
          unless: proc { migrating? || webhooks_descendant? }
        after_destroy_commit proc { queue_webhooks_requests!(event_name(:destroy)) },
          unless: proc { migrating? || webhooks_descendant? }
        after_update_commit proc { queue_webhooks_requests!(event_name(:update)) },
          unless: proc { migrating? || webhooks_descendant? }

        def queue_webhooks_requests!(event)
          unless payload.blank?
            Spree::Webhooks::Endpoints::QueueRequests.call(event: event, payload: payload) 
          end
        end
      end

      private

      def event_name(operation)
        "#{self.class.name.demodulize.tableize.singularize}.#{operation}"
      end

      def webhooks_descendant?
        self.class.module_parents.include?(Spree::Webhooks)
      end

      def payload
        resource_serializer.new(self).serializable_hash
      rescue NameError, NoMethodError
        {}
      end

      def resource_serializer
        demodulized_class_name = self.class.to_s.demodulize
        "Spree::Api::V2::Platform::#{demodulized_class_name}Serializer".constantize
      end

      def migrating?
        ARGV.include?('db:migrate')
      end
    end
  end
end
