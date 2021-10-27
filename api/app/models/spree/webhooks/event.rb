module Spree
  module Webhooks
    class Event < Spree::Webhooks::Base
      validates :name, :subscriber, presence: true

      belongs_to :subscriber, inverse_of: :events, optional: false
    end
  end
end
