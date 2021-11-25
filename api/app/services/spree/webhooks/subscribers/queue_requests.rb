module Spree
  module Webhooks
    module Subscribers
      class QueueRequests
        prepend Spree::ServiceModule::Base

        def call(event_name:, webhook_payload_body:)
          Spree::Webhooks::Subscriber.active.with_urls_for(event_name).each do |subscriber|
            Spree::Webhooks::Subscribers::MakeRequestJob.perform_later(
              webhook_payload_body, event_name, subscriber
            )
          end
        end
      end
    end
  end
end
