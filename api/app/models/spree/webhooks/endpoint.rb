module Spree
  module Webhooks
    class Endpoint < Spree::Webhooks::Base
      validates :url, url: true
    end
  end
end
