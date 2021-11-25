module Spree
  module Webhooks
    module HasWebhooks
      extend ActiveSupport::Concern

      included do
        after_create_commit(proc { queue_webhooks_requests!(inferred_event_name(:create)) })
        after_destroy_commit(proc { queue_webhooks_requests!(inferred_event_name(:delete)) })
        after_update_commit(proc { queue_webhooks_requests!(inferred_event_name(:update)) })

        def queue_webhooks_requests!(event_name)
          return if disable_spree_webhooks? || updating_only_timestamps? || body.blank?

          Spree::Webhooks::Subscribers::QueueRequests.call(body: body, event_name: event_name)
        end

        def self.default_webhook_events
          model_name = name.demodulize.tableize.singularize
          %W[#{model_name}.create #{model_name}.delete #{model_name}.update]
        end

        def self.supported_webhook_events
          events = default_webhook_events
          events += custom_webhook_events if respond_to?(:custom_webhook_events)
          events
        end
      end

      private

      def body
        resource_serializer.new(self).serializable_hash.to_json
      end

      def inferred_event_name(operation)
        "#{self.class.name.demodulize.tableize.singularize}.#{operation}"
      end

      def resource_serializer
        demodulized_class_name = self.class.to_s.demodulize
        "Spree::Api::V2::Platform::#{demodulized_class_name}Serializer".constantize
      end

      def updating_only_timestamps?
        saved_changes.present? && (saved_changes.keys - %w[created_at updated_at]).empty?
      end

      def disable_spree_webhooks?
        ENV['DISABLE_SPREE_WEBHOOKS'] == 'true'
      end
    end
  end
end
