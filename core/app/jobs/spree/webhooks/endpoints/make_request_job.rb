module Spree
  class Webhooks::Endpoints::MakeRequestJob < Spree::BaseJob
    queue_as :spree_webhooks

    def perform(url)
      Spree::Webhooks::Endpoints::MakeRequest.call(url: url)
    end
  end
end
