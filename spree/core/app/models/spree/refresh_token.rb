module Spree
  class RefreshToken < Spree.base_class
    has_prefix_id :rt

    belongs_to :user, polymorphic: true

    has_secure_token :token

    validates :user, :expires_at, presence: true
    # On create only: rows minted before the column exists keep their NULL and
    # stay loadable (they are simply unredeemable), while nothing new is born
    # without the surface it belongs to.
    validates :audience, presence: true, on: :create

    scope :active, -> { where('expires_at > ?', Time.current) }
    scope :expired, -> { where('expires_at <= ?', Time.current) }

    # Tokens minted for one API surface. Always narrow a refresh lookup with
    # this — a token is only redeemable on the surface that issued it.
    scope :for_audience, ->(audience) { where(audience: audience) }

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
          audience: audience,
          expires_at: self.class.default_expiry.from_now,
          ip_address: request_env[:ip_address] || ip_address,
          user_agent: request_env[:user_agent] || user_agent
        )
        destroy!
      end
      new_token
    end

    # Create a refresh token for a user.
    #
    # @param user [Object] the principal the token authenticates
    # @param audience [String] the API surface the token may be redeemed on
    #   (`Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN` and friends).
    #   Required: every redemption path narrows by audience, so an unstamped
    #   token authenticates a login and then fails its first refresh.
    # @param request_env [Hash]
    # @return [Spree::RefreshToken]
    def self.create_for(user, audience:, request_env: {})
      create!(
        user: user,
        audience: audience,
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
