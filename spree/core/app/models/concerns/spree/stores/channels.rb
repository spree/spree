module Spree
  module Stores
    module Channels
      extend ActiveSupport::Concern

      included do
        has_many :channels, class_name: 'Spree::Channel', dependent: :destroy
        has_one :default_channel, -> { default }, class_name: 'Spree::Channel'

        after_create :ensure_default_channel
      end

      def ensure_default_channel
        return if default_channel

        channels.create!(name: 'Online Store', code: Spree::Channel::DEFAULT_CODE)
      end
    end
  end
end
