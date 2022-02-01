module Spree
  module Webhooks
    module HasWebhooks
      extend ActiveSupport::Concern

      included do
        after_create_commit(proc { queue_webhooks_requests!(inferred_event_name(:create)) })
        after_destroy_commit(proc { queue_webhooks_requests!(inferred_event_name(:delete)) })
        after_update_commit(proc { queue_webhooks_requests!(inferred_event_name(:update)) })

        def queue_webhooks_requests!(event_name)
          return if disable_spree_webhooks?
          return if Spree::Webhooks::Subscriber.active.with_urls_for(event_name).none?
          return if update_event?(event_name) && updating_only_ignored_attributes?
          return if webhook_payload_body.blank?

          Spree::Webhooks::Subscribers::QueueRequests.call(
            event_name: event_name, webhook_payload_body: webhook_payload_body, **webhooks_request_options
          )
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

      def webhook_payload_body
        resource_serializer.new(self, include: included_relationships).serializable_hash.to_json
      end

      def inferred_event_name(operation)
        "#{self.class.name.demodulize.tableize.singularize}.#{operation}"
      end

      def included_relationships
        if resource_serializer.relationships_to_serialize
          resource_serializer.relationships_to_serialize.keys
        else
          []
        end
      end

      def resource_serializer
        @resource_serializer ||=
          begin
            demodulized_class_name = self.class.to_s.demodulize
            "Spree::Api::V2::Platform::#{demodulized_class_name}Serializer".constantize
          end
      end

      def updating_only_ignored_attributes?
        (saved_changes.keys - ignored_attributes).empty?
      end

      def ignored_attributes
        timestamps = %w[created_at updated_at deleted_at]
        return timestamps unless self.class.respond_to?(:ignored_attributes_for_update_webhook_event)

        timestamps + self.class.ignored_attributes_for_update_webhook_event
      end

      def update_event?(event_name)
        event_name.end_with?('.update')
      end

      def disable_spree_webhooks?
        ENV['DISABLE_SPREE_WEBHOOKS'] == 'true'
      end

      def webhooks_request_options
        {}
      end
    end
  end
end
