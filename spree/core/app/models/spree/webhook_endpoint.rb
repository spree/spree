# frozen_string_literal: true

require 'ssrf_filter'
require 'resolv'

module Spree
  class WebhookEndpoint < Spree.base_class
    has_prefix_id :whe  # Stripe: we_

    acts_as_paranoid

    include Spree::SingleStoreResource

    encrypts :secret_key, deterministic: true if Rails.configuration.active_record.encryption.include?(:primary_key)

    has_many :webhook_deliveries, class_name: 'Spree::WebhookDelivery', dependent: :destroy_async

    # Host names only a private network answers for. `.local` also covers
    # Kubernetes' `.cluster.local`.
    INTERNAL_HOST_SUFFIXES = %w[.internal .local .localhost .svc].freeze
    # URL errors no retry can change, unlike a host that fails to resolve,
    # which may be a passing DNS outage.
    REFUSED_URL_ERRORS = %i[invalid_url internal_address_not_allowed].freeze

    validates :url, presence: true
    validates_store_uniqueness :url
    validates :active, inclusion: { in: [true, false] }
    # Checked on every save of an active endpoint, not only when the URL
    # changes, so one saved under older rules cannot be renamed or re-enabled
    # unchecked. Switching an endpoint off always succeeds.
    validate :url_must_be_deliverable, if: -> { url.present? && (url_changed? || active?) }
    validate :subscriptions_must_be_event_patterns, if: :will_save_change_to_subscriptions?

    attribute :subscriptions, default: -> { [] }
    normalizes :subscriptions, apply_to_nil: true, with: ->(value) { Array(value).map { |entry| entry.to_s.strip }.reject(&:empty?).uniq }

    before_create :generate_secret_key
    after_create  { @reveal_secret_in_response = true }
    # Re-enabling via a direct `update(active: true)` (e.g., the dashboard's
    # edit form) must also clear the auto-disable bookkeeping so the endpoint
    # rejoins the `enabled` scope. `#enable!` handles this too, but we can't
    # rely on every call site using it.
    before_save :clear_disabled_state_when_reactivated

    self.whitelisted_ransackable_attributes = %w[name url active]
    search_by :url

    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }
    scope :enabled, -> { active.where(disabled_at: nil) }

    # Whether +url+ targets a host the operator trusts despite it resolving to
    # a private address — e.g. a storefront Service in the same Kubernetes
    # cluster. Set via +Spree::Api::Config.webhooks_allowed_internal_hosts+
    # (SPREE_WEBHOOKS_ALLOWED_INTERNAL_HOSTS): an entry matches that exact
    # host, or with a leading dot (".svc.cluster.local") any host under it.
    # Matching is case-insensitive. Operator config only, so a store admin
    # can never point a webhook at an internal address.
    #
    # @param url [String]
    # @return [Boolean]
    def self.allowed_internal_host?(url)
      host = URI.parse(url.to_s).hostname&.downcase
      return false if host.blank?

      allowed_internal_hosts.any? do |entry|
        entry.start_with?('.') ? host.end_with?(entry) : host == entry
      end
    rescue URI::InvalidURIError
      false
    end

    # Spree::Api::Config only exists when spree_api is loaded; without it no
    # webhook is ever delivered, so there is nothing to allow.
    def self.allowed_internal_hosts
      return [] unless defined?(Spree::Api::Config)

      Array(Spree::Api::Config.webhooks_allowed_internal_hosts).filter_map do |entry|
        entry = entry.to_s.strip.downcase
        entry if entry.present? && entry != '.'
      end
    end
    private_class_method :allowed_internal_hosts

    # Why Spree refuses to deliver to this endpoint's URL, or nil when it may.
    #
    # Outside development the host must exist and not be internal, and the URL
    # must use HTTPS; hosts the operator trusts
    # ({.allowed_internal_host?}) are exempt from all three. HTTPS is checked
    # last, so a plain-http URL that is otherwise safe answers
    # `:https_required` and nothing more serious.
    #
    # @return [Symbol, nil] an error key under +url+: `:invalid_url`,
    #   `:internal_address_not_allowed`, `:unresolvable_host` or `:https_required`
    def url_error
      uri = URI.parse(url.to_s)
      return :invalid_url unless uri.is_a?(URI::HTTP) && uri.hostname.present? && uri.userinfo.nil?
      return if Rails.env.development? || self.class.allowed_internal_host?(url)

      addresses = literal_addresses(uri.hostname)
      if addresses.nil?
        return :internal_address_not_allowed if internal_host_name?(uri.hostname)

        addresses = Resolv.getaddresses(uri.hostname)
        return :unresolvable_host if addresses.empty?
      end
      return :internal_address_not_allowed if addresses.any? { |address| private_address?(address) }

      :https_required unless uri.scheme == 'https'
    rescue URI::InvalidURIError, ArgumentError
      :invalid_url
    rescue IPAddr::InvalidAddressError
      :internal_address_not_allowed
    rescue Resolv::ResolvError
      :unresolvable_host
    end

    # Whether Spree refuses this URL for good: malformed, or internal.
    #
    # @return [Boolean]
    def url_refused?
      REFUSED_URL_ERRORS.include?(url_error)
    end

    # Returns the plaintext `secret_key` only on the create response.
    #
    # `@reveal_secret_in_response` is set by the `after_create` callback above
    # — a per-instance flag, not derived from `previous_changes`, so a reload
    # or any subsequent save can't accidentally re-expose the secret.
    #
    # @return [String, nil]
    def secret_key_for_response
      @reveal_secret_in_response ? secret_key : nil
    end

    # Number of consecutive failed deliveries before auto-disabling
    AUTO_DISABLE_THRESHOLD = 15

    MAX_SUBSCRIPTIONS = 200
    MAX_SUBSCRIPTION_LENGTH = 100
    SUBSCRIPTION_SEGMENT = /\A[a-zA-Z0-9_-]+\z/

    # Whether +value+ is a shape `subscriptions` accepts: `*`, an event name,
    # or a name with `*` in place of whole segments (`order.*`, `*.created`).
    # Anything else — regexp syntax above all — is refused before it is
    # stored, so the matcher only ever sees names and segment wildcards.
    #
    # @param value [Object]
    # @return [Boolean]
    def self.event_pattern?(value)
      return false unless value.is_a?(String) && value.length.between?(1, MAX_SUBSCRIPTION_LENGTH)

      value.split('.', -1).all? { |segment| segment == '*' || segment.match?(SUBSCRIPTION_SEGMENT) }
    end

    # Check if this endpoint is subscribed to a specific event.
    #
    # Events whose payload carries a live credential (a password reset token)
    # reach only an endpoint that names them — never through `*` or a pattern —
    # since receiving one is as good as holding the account.
    #
    # @param event_name [String] the event name to check
    # @return [Boolean]
    def subscribed_to?(event_name)
      return subscriptions.to_a.include?(event_name) if Spree::Events.catalog.credential?(event_name)
      return true if subscriptions.blank?

      subscriptions.any? { |subscription| Spree::Event.matches?(event_name, subscription) }
    end

    # The credential-carrying events this endpoint names.
    #
    # @return [Array<Spree::Events::Catalog::Entry>]
    def credential_subscriptions
      Spree::Events.catalog.credential_events(subscriptions.to_a)
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

    def subscriptions_must_be_event_patterns
      entries = subscriptions.to_a
      errors.add(:subscriptions, :too_many, count: MAX_SUBSCRIPTIONS) if entries.size > MAX_SUBSCRIPTIONS

      rejected = entries.reject { |entry| self.class.event_pattern?(entry) }
      return if rejected.empty?

      errors.add(:subscriptions, :invalid_pattern, entries: rejected.first(5).map { |entry| entry.truncate(40) }.join(', '))
    end

    def clear_disabled_state_when_reactivated
      return unless will_save_change_to_active? && active

      self.disabled_at = nil
      self.disabled_reason = nil
    end

    def url_must_be_deliverable
      error = url_error
      errors.add(:url, error) if error
    end

    # The forms a resolver answers nothing for — `127.1`, a decimal or hex
    # IPv4, an IPv6 address — read as the address they are; nil for a name.
    def literal_addresses(host)
      Socket.getaddrinfo(host, nil, nil, Socket::SOCK_STREAM, nil, Socket::AI_NUMERICHOST).map { |entry| entry[3] }.uniq
    rescue SocketError
      nil
    end

    def internal_host_name?(host)
      name = host.downcase.chomp('.')
      name.exclude?('.') || INTERNAL_HOST_SUFFIXES.any? { |suffix| name.end_with?(suffix) }
    end

    def private_address?(address)
      ip = IPAddr.new(address)
      (SsrfFilter::IPV4_BLACKLIST + SsrfFilter::IPV6_BLACKLIST).any? { |range| range.include?(ip) }
    end
  end
end
