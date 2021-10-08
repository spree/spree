module Spree
  module Webhooks
    module Endpoints
      class MakeRequestJob < Spree::BaseJob
        queue_as :spree_webhooks

        def perform(body, url)
          Spree::Webhooks::Endpoints::MakeRequest.new(body: body, url: url).call
        end
      end
    end
  end
end
