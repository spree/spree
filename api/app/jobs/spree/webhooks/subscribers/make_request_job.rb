module Spree
  module Webhooks
    module Subscribers
      class MakeRequestJob < Spree::BaseJob
        queue_as :spree_webhooks

        def perform(body, event_name, subscriber)
          Spree::Webhooks::Subscribers::HandleRequest.new(
            body: body, event_name: event_name, subscriber: subscriber
          ).call
        end
      end
    end
  end
end
