module Spree
  # RFC 9728 metadata: which authorization server guards a protected surface
  # and what it will accept. Never persisted — assembled per request, since
  # the origin a client reached is the one it can use.
  class OauthProtectedResource
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :resource, :string
    attribute :authorization_servers, default: -> { [] }
    # Exactly what the authorization server accepts. Advertising one scope
    # more than it knows turns every connection into "the requested scope is
    # invalid", because a client with no scope challenge asks for everything
    # listed here.
    attribute :scopes_supported, default: -> { [] }
    attribute :bearer_methods_supported, default: -> { ['header'] }
    attribute :resource_documentation, :string

    validates :resource, presence: true
  end
end
