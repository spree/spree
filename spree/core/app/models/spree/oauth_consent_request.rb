module Spree
  # What a client is asking a merchant to approve, as the consent screen
  # needs it. Never persisted — approving it writes an
  # {Spree::OauthAccessGrant} instead.
  class OauthConsentRequest
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :client_name, :string
    # Every permission the requested scopes imply, expanded, so the screen
    # lists what is actually being handed over rather than the shorthand the
    # client asked for.
    attribute :scopes, default: -> { [] }
    # Of those, the ones this person may hand over. A grant can only narrow
    # the approver's own authority, so anything they do not hold is not
    # offered.
    attribute :grantable_scopes, default: -> { [] }
    attribute :resource, :string
    attribute :redirect_uri, :string

    validates :client_name, :redirect_uri, presence: true
  end
end
