module Spree
  module Webhooks
    module HasWebhooks
      extend ActiveSupport::Concern

      included do
        after_create_commit(proc { queue_webhooks_requests!(event_name(:create)) })
        after_destroy_commit(proc { queue_webhooks_requests!(event_name(:destroy)) })
        after_update_commit(proc { queue_webhooks_requests!(event_name(:update)) })

        def queue_webhooks_requests!(event)
          return if disable_spree_webhooks? || body.blank?

          Spree::Webhooks::Subscribers::QueueRequests.call(event: event, body: body)
        end

        def self.default_webhook_events
          model_name = name.demodulize.tableize.singularize
          %W[#{model_name}.create #{model_name}.delete #{model_name}.update]
        end

        def self.supported_webhook_events
          events = default_webhook_events
          events += custom_supported_events if respond_to?(:custom_supported_events)
          events
        end
      end

      private

      def event_name(operation)
        "#{self.class.name.demodulize.tableize.singularize}.#{operation}"
      end

      def body
        resource_serializer.new(self).serializable_hash.to_json
      end

      def resource_serializer
        demodulized_class_name = self.class.to_s.demodulize
        "Spree::Api::V2::Platform::#{demodulized_class_name}Serializer".constantize
      end

      def disable_spree_webhooks?
        ENV['DISABLE_SPREE_WEBHOOKS'] == 'true'
      end
    end
  end
end
