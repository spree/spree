module Spree
  module Webhooks
    class Endpoint < Spree::Webhooks::Base
      validates :url, presence: true
    end
  end
end
