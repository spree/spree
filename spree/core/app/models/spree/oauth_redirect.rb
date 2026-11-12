module Spree
  # Where to send the browser once the merchant has decided, carrying either
  # the authorization code or the refusal. Never persisted.
  class OauthRedirect
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :redirect_uri, :string

    validates :redirect_uri, presence: true
  end
end
