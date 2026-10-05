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

    # When someone last used this application, for the connections screen.
    #
    # @return [ActiveSupport::TimeWithZone, nil]
    def last_used_at
      access_tokens.order(:created_at).last&.created_at
    end
  end
end
