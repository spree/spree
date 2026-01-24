module Spree
  class UserIdentity < Spree::Base
    has_prefix_id :uid

    belongs_to :user, polymorphic: true, optional: false

    validates :provider, presence: true
    validates :uid, presence: true, uniqueness: { scope: [:provider, :user_type] }

    # Providers
    PROVIDERS = %w[email google facebook github apple].freeze

    validates :provider, inclusion: { in: PROVIDERS }

    # Store provider-specific data
    # info: JSON field with provider-specific data (name, avatar, etc)
    # access_token: encrypted OAuth access token
    # refresh_token: encrypted OAuth refresh token
    # expires_at: token expiration timestamp

    # Find or create user from OAuth data
    def self.find_or_create_from_oauth(provider:, uid:, info:, tokens: {}, user_class: nil)
      user_class ||= Spree.user_class
      user_type = user_class.name

      identity = find_by(provider: provider, uid: uid, user_type: user_type)

      if identity
        # Update existing identity with fresh tokens
        identity.update(
          info: info,
          access_token: tokens[:access_token],
          refresh_token: tokens[:refresh_token],
          expires_at: tokens[:expires_at]
        )
        identity.user
      else
        # Create new user and identity
        create_user_from_oauth(
          provider: provider,
          uid: uid,
          info: info,
          tokens: tokens,
          user_class: user_class
        )
      end
    end

    def self.create_user_from_oauth(provider:, uid:, info:, tokens: {}, user_class: nil)
      user_class ||= Spree.user_class

      user = user_class.create!(
        email: info[:email] || generate_temp_email(provider, uid),
        password: SecureRandom.hex(32), # Random password for OAuth users
        first_name: info[:first_name],
        last_name: info[:last_name]
      )

      user.identities.create!(
        provider: provider,
        uid: uid,
        info: info,
        access_token: tokens[:access_token],
        refresh_token: tokens[:refresh_token],
        expires_at: tokens[:expires_at]
      )

      user
    end

    def self.generate_temp_email(provider, uid)
      "#{provider}-#{uid}@temporary.example.com"
    end

    def expired?
      expires_at && expires_at < Time.current
    end
  end
end
