module Spree
  module Webhooks
    module Subscribers
      class MakeRequestJob < Spree::BaseJob
        queue_as :spree_webhooks

        def perform(body, event, subscriber_id, url)
          Spree::Webhooks::Subscribers::HandleRequest.new(
            body: body, event: event, subscriber: subscriber
          ).call
        end
      end
    end
  end
end
