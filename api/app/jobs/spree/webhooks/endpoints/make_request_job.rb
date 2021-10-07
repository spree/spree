module Spree
  module Webhooks
    module Endpoints
      class MakeRequestJob < Spree::BaseJob
        queue_as :spree_webhooks

        def perform(body, url)
          Spree::Webhooks::Endpoints::MakeRequest.call(body: body, url: url)
        end
      end
    end
  end
end
