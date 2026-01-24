# frozen_string_literal: true

module Spree
  class WebhookEndpoint < Spree.base_class
    has_prefix_id :whe  # Stripe: we_

    acts_as_paranoid

    include Spree::SingleStoreResource

    belongs_to :store, class_name: 'Spree::Store'
    has_many :webhook_deliveries, class_name: 'Spree::WebhookDelivery', dependent: :destroy_async

    validates :store, :url, presence: true
    validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: :invalid_url }
    validates :active, inclusion: { in: [true, false] }

    before_create :generate_secret_key

    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }

    # Check if this endpoint is subscribed to a specific event
    #
    # @param event_name [String] the event name to check
    # @return [Boolean]
    def subscribed_to?(event_name)
      return true if subscriptions.blank? || subscriptions.include?('*')

      subscriptions.any? do |subscription|
        if subscription.include?('*')
          pattern = Regexp.escape(subscription).gsub('\*', '.*')
          event_name.match?(Regexp.new("^#{pattern}$"))
        else
          subscription == event_name
        end
      end
    end

    # Returns all events this endpoint is subscribed to
    #
    # @return [Array<String>]
    def subscribed_events
      return ['*'] if subscriptions.blank?

      subscriptions
    end

    private

    def generate_secret_key
      self.secret_key ||= SecureRandom.hex(32)
    end
  end
end
