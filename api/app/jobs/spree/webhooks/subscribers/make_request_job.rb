module Spree
  module Webhooks
    module Subscribers
      class MakeRequestJob < Spree::BaseJob
        queue_as :spree_webhooks

        def perform(body, event, url)
          Spree::Webhooks::Subscribers::HandleRequest.new(body: body, event: event, url: url).call
        end
      end
    end
  end
end
