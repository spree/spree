module Spree
  module Webhooks
    class Subscriber < Spree::Webhooks::Base
      validates :url, 'spree/url': true, presence: true

      scope :active, -> { where(active: true) }
    end
  end
end
