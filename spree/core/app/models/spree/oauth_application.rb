module Spree
  # A registered OAuth client: an MCP client today, a marketplace app or a
  # merchant-approved integration later. Clients are pre-registered rather
  # than dynamically registered — RFC 7591 is deprecated, and the consumer
  # clients worth supporting need no registration endpoint.
  class OauthApplication < Spree.base_class
    include ::Doorkeeper::Orm::ActiveRecord::Mixins::Application

    self.table_name = 'spree_oauth_applications'

    has_prefix_id :oauthapp

    belongs_to :store, class_name: 'Spree::Store'

    has_many :access_grants,
             class_name: 'Spree::OauthAccessGrant',
             foreign_key: :application_id,
             dependent: :destroy
    has_many :access_tokens,
             class_name: 'Spree::OauthAccessToken',
             foreign_key: :application_id,
             dependent: :destroy

    # Tokens that still work. A revoked or expired one says nothing about
    # what a merchant has granted, and showing its scopes after a revoke
    # reads as if the revoke did not take.
    has_many :live_access_tokens,
             -> { where(revoked_at: nil) },
             class_name: 'Spree::OauthAccessToken',
             foreign_key: :application_id,
             inverse_of: :application,
             dependent: nil

    # What this application may currently do, as permission keys.
    #
    # Read from the tokens rather than the registration: a client is
    # registered once and granted per consent, so the registration's own
    # `scopes` column stays empty.
    #
    # @return [Array<String>]
    def live_token_scopes
      live_access_tokens.flat_map { |token| token.scopes.to_a }.uniq.sort
    end

    # When this application was last granted a token that still works.
    #
    # @return [ActiveSupport::TimeWithZone, nil]
    def last_used_at
      live_access_tokens.map(&:created_at).max
    end
  end
end
