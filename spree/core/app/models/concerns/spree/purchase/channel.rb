module Spree
  module Purchase
    module Channel
      extend ActiveSupport::Concern

      included do
        belongs_to :channel, class_name: 'Spree::Channel'

        validates :channel, presence: true

        before_validation :ensure_channel_presence
      end

      def ensure_channel_presence
        return if channel_id.present?

        self.channel = store&.default_channel
      end
    end
  end
end
