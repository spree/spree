module Spree
  module Webhooks
    module Endpoints
      class MakeRequestJob < Spree::BaseJob
        queue_as :spree_webhooks

        def perform(payload, url)
          Spree::Webhooks::Endpoints::MakeRequest.call(payload: payload, url: url)
        end
      end
    end
  end
end
