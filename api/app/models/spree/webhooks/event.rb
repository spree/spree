module Spree
  module Webhooks
    class Event < Spree::Webhooks::Base
      validates :name, presence: true
      validates :subscriber, presence: true, on: :update

      belongs_to :subscriber, inverse_of: :events, optional: true

      self.whitelisted_ransackable_associations = %w[subscriber]
      self.whitelisted_ransackable_attributes = %w[name request_errors response_code success url]
    end
  end
end
