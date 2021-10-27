module Spree
  module Webhooks
    class Event < Spree::Webhooks::Base
      validates :name, presence: true

      belongs_to :subscriber, inverse_of: :events, optional: false
    end
  end
end
