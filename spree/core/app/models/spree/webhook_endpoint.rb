# frozen_string_literal: true

require 'ssrf_filter'
require 'resolv'

module Spree
  class WebhookEndpoint < Spree.base_class
    has_prefix_id :whe  # Stripe: we_

    acts_as_paranoid

    include Spree::SingleStoreResource

    encrypts :secret_key, deterministic: true if Rails.configuration.active_record.encryption.include?(:primary_key)

    belongs_to :store, class_name: 'Spree::Store'
    has_many :webhook_deliveries, class_name: 'Spree::WebhookDelivery', dependent: :destroy_async

    validates :store, :url, presence: true
    validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: :invalid_url }
    validates :active, inclusion: { in: [true, false] }
    validate :url_must_not_resolve_to_private_ip, if: -> { !Rails.env.development? && url.present? && url_changed? }

    before_create :generate_secret_key

    self.whitelisted_ransackable_attributes = %w[name url active]

    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }
    scope :enabled, -> { active.where(disabled_at: nil) }

    # Number of consecutive failed deliveries before auto-disabling
    AUTO_DISABLE_THRESHOLD = 15

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

    # Send a test/ping webhook to verify the endpoint is reachable.
    # Creates a delivery record and queues it for delivery.
    #
    # @return [Spree::WebhookDelivery]
    def send_test!
      delivery = webhook_deliveries.create!(
        event_name: 'webhook.test',
        payload: {
          id: SecureRandom.uuid,
          name: 'webhook.test',
          created_at: Time.current.iso8601,
          data: { message: 'This is a test webhook from Spree.' },
          metadata: { spree_version: Spree.version }
        }
      )

      delivery.queue_for_delivery!
      delivery
    end

    # Disable this endpoint due to repeated failures.
    # Sends a notification email to the store staff.
    #
    # @param reason [String]
    # @param notify [Boolean] whether to send an email notification (default: true)
    def disable!(reason: 'Automatically disabled after repeated delivery failures', notify: true)
      update!(active: false, disabled_reason: reason, disabled_at: Time.current)
      Spree::WebhookMailer.endpoint_disabled(self).deliver_later if notify
    end

    # Re-enable a previously disabled endpoint.
    def enable!
      update!(active: true, disabled_reason: nil, disabled_at: nil)
    end

    # Check if the endpoint was auto-disabled
    #
    # @return [Boolean]
    def auto_disabled?
      disabled_at.present?
    end

    # Check if auto-disable threshold has been reached
    # and disable if so.
    def check_auto_disable!
      return if auto_disabled?

      consecutive_failures = webhook_deliveries
        .where(success: false)
        .where.not(delivered_at: nil)
        .order(delivered_at: :desc)
        .limit(AUTO_DISABLE_THRESHOLD)

      return if consecutive_failures.count < AUTO_DISABLE_THRESHOLD

      # Verify they're all failures (no successes interspersed)
      last_success = webhook_deliveries.successful.order(delivered_at: :desc).pick(:delivered_at)
      oldest_failure = consecutive_failures.last&.delivered_at

      if last_success.nil? || (oldest_failure && oldest_failure > last_success)
        disable!
      end
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
