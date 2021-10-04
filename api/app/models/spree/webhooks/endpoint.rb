module Spree
  module Webhooks
    class Endpoint < Spree::Webhooks::Base
      validates :url, :'spree/webhooks/validators/url' => true
    end
  end
end
