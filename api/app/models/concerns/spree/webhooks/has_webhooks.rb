module Spree
  module Webhooks
    module HasWebhooks
      extend ActiveSupport::Concern

      included do
        after_create_commit(proc { queue_webhooks_requests!(event_name(:create)) })
        after_destroy_commit(proc { queue_webhooks_requests!(event_name(:destroy)) })
        after_update_commit(proc { queue_webhooks_requests!(event_name(:update)) })

        def queue_webhooks_requests!(event)
          return if disable_spree_webhooks? || (event_body = body(event: event)).blank?

          Spree::Webhooks::Subscribers::QueueRequests.call(event: event, body: event_body)
        end
      end

      private

      def event_name(operation)
        "#{self.class.name.demodulize.tableize.singularize}.#{operation}"
      end

      def body(event:)
        resource_serializer.new(self, serializer_params(event: event)).serializable_hash.to_json
      end

      def resource_serializer
        demodulized_class_name = self.class.to_s.demodulize
        "Spree::Api::V2::Platform::#{demodulized_class_name}Serializer".constantize
      end

      def serializer_params(event:)
        {
          params: {
            webhook_metadata: true,
            event: event
          }
        }
      end

      def disable_spree_webhooks?
        ENV['DISABLE_SPREE_WEBHOOKS'] == 'true'
      end
    end
  end
end
