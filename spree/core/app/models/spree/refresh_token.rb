module Spree
  class RefreshToken < Spree.base_class
    has_prefix_id :rt

    belongs_to :user, polymorphic: true

    has_secure_token :token

    validates :user, :expires_at, presence: true

    scope :active, -> { where('expires_at > ?', Time.current) }
    scope :expired, -> { where('expires_at <= ?', Time.current) }

    def expired?
      expires_at <= Time.current
    end

    # Rotate: destroy this token and create a new one.
    # Returns the new token.
    def rotate!(request_env: {})
      new_token = nil
      transaction do
        new_token = self.class.create!(
          user: user,
          expires_at: self.class.default_expiry.from_now,
          ip_address: request_env[:ip_address] || ip_address,
          user_agent: request_env[:user_agent] || user_agent
        )
        destroy!
      end
      new_token
    end

    # Create a refresh token for a user
    def self.create_for(user, request_env: {})
      create!(
        user: user,
        expires_at: default_expiry.from_now,
        ip_address: request_env[:ip_address],
        user_agent: request_env[:user_agent]
      )
    end

    # Revoke all refresh tokens for a user (e.g., on password change)
    def self.revoke_all_for(user)
      where(user: user).delete_all
    end

    # Clean up expired tokens
    def self.cleanup_expired!
      expired.delete_all
    end

    def self.default_expiry
      Spree::Api::Config[:refresh_token_expiry].seconds
    rescue StandardError
      30.days
    end
  end
end
