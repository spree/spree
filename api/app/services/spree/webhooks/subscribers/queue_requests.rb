module Spree
  module Webhooks
    module Subscribers
      class QueueRequests
        prepend Spree::ServiceModule::Base

        def call(event_name:, webhook_payload_body:, record: nil, **options)
          filtered_subscribers(event_name, webhook_payload_body, record, options).each do |subscriber|
            Spree::Webhooks::Subscribers::MakeRequestJob.perform_later(
              webhook_payload_body, event_name, subscriber
            )
          end
        end

        private

        def filtered_subscribers(event_name, webhook_payload_body, record, options)
          Spree::Current.webhooks_subscribers.map do |subscriber|
            if subscriber.supports_event?(event_name)
              subscriber
            end
          end.compact
        end
      end
    end
  end
end
