module Spree
  module Webhooks
    class Endpoint < Spree::Webhooks::Base
      validates :url, 'spree/url': true
    end
  end
end
