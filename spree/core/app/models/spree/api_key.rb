module Spree
  class ApiKey < Spree.base_class
    has_prefix_id :key  # Spree-specific: api key

    KEY_TYPES = %w[publishable secret].freeze
    PREFIXES = { 'publishable' => 'pk_', 'secret' => 'sk_' }.freeze
    TOKEN_LENGTH = 24

    # Admin API authorization scopes. Granted to secret keys at creation; checked
    # by ScopedAuthorization on every admin request. See
    # docs/plans/5.5-admin-api-key-scopes.md for the full design.
    SCOPES = %w[
      read_orders write_orders
      read_products write_products
      read_customers write_customers
      read_payments write_payments
      read_fulfillments write_fulfillments
      read_refunds write_refunds
      read_gift_cards write_gift_cards
      read_store_credits write_store_credits
      read_categories write_categories
      read_settings write_settings
      read_webhooks write_webhooks
      read_dashboard
      read_all write_all
    ].freeze

    # Scopes are stored in a JSON column (jsonb on PostgreSQL, json elsewhere).
    # The DB driver handles array <-> JSON conversion; no `serialize` needed.
    attribute :scopes, default: []

    def scopes=(value)
      super(Array(value).map(&:to_s).reject(&:blank?))
    end

    # Returns the raw token value. For publishable keys this is the persisted
    # +token+ column. For secret keys it is only available in memory immediately
    # after creation (not persisted).
    #
    # @return [String, nil]
    def plaintext_token
      publishable? ? token : @plaintext_token
    end

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :created_by, polymorphic: true, optional: true
    belongs_to :revoked_by, polymorphic: true, optional: true

    validates :name, presence: true
    validates :key_type, presence: true, inclusion: { in: KEY_TYPES }
    validates :token, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }, if: :publishable?
    validates :token_digest, presence: true, uniqueness: true, if: :secret?
    validates :token_prefix, presence: true, if: :secret?
    validates :store, presence: true
    validates :scopes, presence: true, if: :secret?
    validate :validate_known_scopes, if: :secret?

    before_validation :generate_token, on: :create

    scope :active, -> { where(revoked_at: nil) }
    scope :revoked, -> { where.not(revoked_at: nil) }
    scope :publishable, -> { where(key_type: 'publishable') }
    scope :secret, -> { where(key_type: 'secret') }

    # Finds an active secret API key by computing the HMAC-SHA256 digest
    # of the provided plaintext token and looking up by +token_digest+.
    #
    # @param plaintext [String] the raw secret key (e.g. "sk_abc123...")
    # @return [Spree::ApiKey, nil] the matching active secret key, or nil
    def self.find_by_secret_token(plaintext)
      return nil if plaintext.blank?

      digest = compute_token_digest(plaintext)
      active.secret.find_by(token_digest: digest)
    end

    # Computes the HMAC-SHA256 hex digest for a given plaintext token.
    #
    # @param plaintext [String] the raw token value
    # @return [String] the hex-encoded HMAC-SHA256 digest
    def self.compute_token_digest(plaintext)
      OpenSSL::HMAC.hexdigest('SHA256', hmac_secret, plaintext)
    end

    # Returns the HMAC secret used for token hashing.
    #
    # @return [String] the application's secret key base
    def self.hmac_secret
      Rails.application.secret_key_base
    end

    # @return [Boolean] whether this is a publishable (Store API) key
    def publishable?
      key_type == 'publishable'
    end

    # @return [Boolean] whether this is a secret (Admin API) key
    def secret?
      key_type == 'secret'
    end

    # @return [Boolean] whether this key has not been revoked
    def active?
      revoked_at.nil?
    end

    # Revokes this API key by setting +revoked_at+ to the current time.
    #
    # @param user [Object, nil] the user who performed the revocation
    # @return [Boolean] true if the update succeeded
    def revoke!(user = nil)
      update!(revoked_at: Time.current, revoked_by: user)
    end

    # Whether this key carries the given scope. `write_*` implies the matching
    # `read_*`; `read_all` / `write_all` aliases expand to every read / read+write
    # scope respectively.
    #
    # @param scope [String]
    # @return [Boolean]
    def has_scope?(scope)
      scope = scope.to_s
      return true if scopes.include?(scope)
      return true if scope.start_with?('read_') && scopes.include?("write_#{scope.delete_prefix('read_')}")
      return true if scopes.include?('write_all')
      return true if scope.start_with?('read_') && scopes.include?('read_all')

      false
    end

    private

    def validate_known_scopes
      invalid = scopes - SCOPES
      errors.add(:scopes, "contains unknown scopes: #{invalid.join(', ')}") if invalid.any?
    end

    # Generates the token on creation. For publishable keys, stores the raw token
    # in the +token+ column. For secret keys, computes an HMAC-SHA256 digest stored
    # in +token_digest+, saves the first 12 characters as +token_prefix+ for display,
    # and exposes the raw value via {#plaintext_token} (available only in memory).
    def generate_token
      raw_token = "#{PREFIXES[key_type]}#{SecureRandom.base58(TOKEN_LENGTH)}"

      if secret?
        @plaintext_token = raw_token
        self.token_prefix = raw_token[0, 12]
        self.token_digest = self.class.compute_token_digest(raw_token)
        self.token = nil
      else
        self.token ||= raw_token
      end
    end
  end
end
