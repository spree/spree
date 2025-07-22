module Spree
  module Webhooks
    class Event < Spree::Webhooks::Base
      validates :name, :subscriber, presence: true

      belongs_to :subscriber, inverse_of: :events, optional: false

      self.whitelisted_ransackable_associations = %w[subscriber]
      self.whitelisted_ransackable_attributes = %w[name request_errors response_code success url]

      # Computes the base64-encoded HMAC SHA256 signature of the event for the given payload.
      #
      # @param payload [Hash, String] The payload for to the webhook subscriber.
      # @return [String]
      def signature_for(payload)
        EventSignature.new(self, payload).computed_signature
      end
    end
  end
end
