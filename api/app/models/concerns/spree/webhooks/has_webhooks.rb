module Spree
  module Webhooks
    module HasWebhooks
      extend ActiveSupport::Concern

      included do
        after_create_commit(proc { queue_webhooks_requests!(event_name(:create)) })
        after_destroy_commit(proc { queue_webhooks_requests!(event_name(:delete)) })
        after_update_commit(proc { queue_webhooks_requests!(event_name(:update)) })

        def queue_webhooks_requests!(event)
          return if disable_spree_webhooks? || updating_only_timestamps? || (event_body = body(event: event)).blank?

          # Spree::Webhooks::Subscribers::QueueRequests.call(event: event, body: event_body.tap{|x| puts x if event == 'product.create'})
          Spree::Webhooks::Subscribers::QueueRequests.call(event: event, body: event_body)
        end
      end

      private

      def event_record(event)
        Spree::Webhooks::Event.create(name: event)
      end

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
        created_event = event_record(event)
        {
          params: {
            event_created_at: created_event.created_at,
            event_id: created_event.id,
            event_type: event,
            webhook_metadata: true
          }
        }
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
