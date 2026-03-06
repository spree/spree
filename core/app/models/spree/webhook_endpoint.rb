# frozen_string_literal: true

require 'ssrf_filter'
require 'resolv'

module Spree
  class WebhookEndpoint < Spree.base_class
    acts_as_paranoid

    include Spree::SingleStoreResource

    encrypts :secret_key, deterministic: true if Rails.configuration.active_record.encryption.include?(:primary_key)

    belongs_to :store, class_name: 'Spree::Store'
    has_many :webhook_deliveries, class_name: 'Spree::WebhookDelivery', dependent: :destroy_async

    validates :store, :url, presence: true
    validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: :invalid_url }
    validates :active, inclusion: { in: [true, false] }
    validate :url_must_not_resolve_to_private_ip, if: -> { url.present? && url_changed? }

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

    def url_must_not_resolve_to_private_ip
      uri = URI.parse(url)
      blacklist = SsrfFilter::IPV4_BLACKLIST + SsrfFilter::IPV6_BLACKLIST
      addresses = Resolv.getaddresses(uri.host)
      if addresses.any? { |addr| blacklist.any? { |range| range.include?(IPAddr.new(addr)) } }
        errors.add(:url, :internal_address_not_allowed)
      end
    rescue URI::InvalidURIError, Resolv::ResolvError, IPAddr::InvalidAddressError, ArgumentError
      # URI format validation handles invalid URLs; DNS failures are not SSRF
    end
  end
end
