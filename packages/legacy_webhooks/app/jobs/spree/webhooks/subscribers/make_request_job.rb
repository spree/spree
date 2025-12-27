module Spree
  module Webhooks
    module Subscribers
      class MakeRequestJob < Spree::BaseJob
        queue_as :spree_webhooks

        def perform(webhook_payload_body, event_name, subscriber)
          Spree::Webhooks::Subscribers::HandleRequest.new(
            event_name: event_name,
            subscriber: subscriber,
            webhook_payload_body: webhook_payload_body
          ).call
        end
      end
    end
  end
end
