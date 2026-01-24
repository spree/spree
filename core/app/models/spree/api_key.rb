module Spree
  class ApiKey < Spree.base_class
    has_prefix_id :key  # Spree-specific: api key

    KEY_TYPES = %w[publishable secret].freeze
    PREFIXES = { 'publishable' => 'pk_', 'secret' => 'sk_' }.freeze
    TOKEN_LENGTH = 24

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :created_by, polymorphic: true, optional: true
    belongs_to :revoked_by, polymorphic: true, optional: true

    validates :name, presence: true
    validates :key_type, presence: true, inclusion: { in: KEY_TYPES }
    validates :token, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }

    before_validation :generate_token, on: :create

    scope :active, -> { where(revoked_at: nil) }
    scope :revoked, -> { where.not(revoked_at: nil) }
    scope :publishable, -> { where(key_type: 'publishable') }
    scope :secret, -> { where(key_type: 'secret') }

    def publishable?
      key_type == 'publishable'
    end

    def secret?
      key_type == 'secret'
    end

    def active?
      revoked_at.nil?
    end

    def revoke!(user = nil)
      update!(revoked_at: Time.current, revoked_by: user)
    end

    private

    def generate_token
      self.token ||= "#{PREFIXES[key_type]}#{SecureRandom.base58(TOKEN_LENGTH)}"
    end
  end
end
